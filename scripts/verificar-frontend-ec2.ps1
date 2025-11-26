# Script para verificar e corrigir o frontend no EC2
# Uso: .\verificar-frontend-ec2.ps1

Write-Host "=== Verificando Frontend no EC2 ===" -ForegroundColor Green
Write-Host ""

$AWS_REGION = "sa-east-1"

# Obter diretório do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$infraDir = Join-Path $projectRoot "infra"

# 1. Obter IP e Instance ID do EC2
Write-Host "1. Obtendo informações do EC2 Frontend..." -ForegroundColor Yellow
Push-Location $infraDir

try {
    $EC2_IP = terraform output -raw ec2_frontend_public_ip 2>&1 | Out-String
    $EC2_IP = $EC2_IP.Trim().Trim('"')
    
    $INSTANCE_ID = terraform output -raw ec2_frontend_instance_id 2>&1 | Out-String
    $INSTANCE_ID = $INSTANCE_ID.Trim().Trim('"')
    
    if ([string]::IsNullOrEmpty($EC2_IP) -or $EC2_IP -match "Warning|Error") {
        throw "Não foi possível obter IP do EC2"
    }
    
    if ([string]::IsNullOrEmpty($INSTANCE_ID) -or $INSTANCE_ID -match "Warning|Error") {
        throw "Não foi possível obter Instance ID do EC2"
    }
    
    Write-Host "✅ EC2 IP: $EC2_IP" -ForegroundColor Green
    Write-Host "✅ Instance ID: $INSTANCE_ID" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRO: $_" -ForegroundColor Red
    Write-Host "   Usando valores conhecidos..." -ForegroundColor Yellow
    $EC2_IP = "54.233.235.180"
    $INSTANCE_ID = "i-008d42b0e37871c92"
    Write-Host "   IP: $EC2_IP" -ForegroundColor Cyan
    Write-Host "   Instance ID: $INSTANCE_ID" -ForegroundColor Cyan
} finally {
    Pop-Location
}

Write-Host ""

# 2. Verificar status da instância
Write-Host "2. Verificando status da instância EC2..." -ForegroundColor Yellow
$instanceStatus = aws ec2 describe-instance-status `
    --instance-ids $INSTANCE_ID `
    --region $AWS_REGION `
    --query 'InstanceStatuses[0].InstanceState.Name' `
    --output text 2>&1

if ($instanceStatus -eq "running") {
    Write-Host "✅ Instância está rodando" -ForegroundColor Green
} else {
    Write-Host "❌ Instância não está rodando! Status: $instanceStatus" -ForegroundColor Red
    Write-Host "   Iniciando instância..." -ForegroundColor Yellow
    aws ec2 start-instances --instance-ids $INSTANCE_ID --region $AWS_REGION | Out-Null
    Write-Host "   Aguarde alguns minutos para a instância iniciar..." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 3. Obter URL do ECR Frontend
Write-Host "3. Obtendo URL do repositório ECR..." -ForegroundColor Yellow
Push-Location $infraDir

try {
    $ECR_FRONTEND_URL = terraform output -raw ecr_frontend_repository_url 2>&1 | Out-String
    $ECR_FRONTEND_URL = $ECR_FRONTEND_URL.Trim()
    
    if ([string]::IsNullOrEmpty($ECR_FRONTEND_URL) -or $ECR_FRONTEND_URL -match "Warning|Error") {
        throw "Não foi possível obter URL do ECR"
    }
    
    Write-Host "✅ ECR Frontend URL: $ECR_FRONTEND_URL" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRO: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host ""

# 4. Criar script para executar no EC2
Write-Host "4. Criando script de deploy para EC2..." -ForegroundColor Yellow

$deployScript = @"
#!/bin/bash
set -e

echo "=== Deploy do Frontend no EC2 ==="

# Atualizar sistema
echo "1. Atualizando sistema..."
sudo yum update -y

# Instalar Docker se não estiver instalado
if ! command -v docker &> /dev/null; then
    echo "2. Instalando Docker..."
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
    echo "✅ Docker instalado"
else
    echo "✅ Docker já está instalado"
fi

# Autenticar no ECR
echo "3. Autenticando no ECR..."
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin $ECR_FRONTEND_URL

# Parar e remover container antigo se existir
echo "4. Parando containers antigos..."
sudo docker stop frontend-nuvem 2>/dev/null || true
sudo docker rm frontend-nuvem 2>/dev/null || true

# Remover imagem antiga
echo "5. Removendo imagem antiga..."
sudo docker rmi ${ECR_FRONTEND_URL}:latest 2>/dev/null || true

# Pull da imagem mais recente
echo "6. Fazendo pull da imagem mais recente..."
sudo docker pull ${ECR_FRONTEND_URL}:latest

# Executar novo container
echo "7. Iniciando novo container..."
sudo docker run -d \
    --name frontend-nuvem \
    -p 80:80 \
    --restart unless-stopped \
    ${ECR_FRONTEND_URL}:latest

# Verificar se está rodando
echo "8. Verificando status..."
sleep 5
sudo docker ps | grep frontend-nuvem

echo ""
echo "✅ Deploy concluído!"
echo "Frontend disponível em: http://$EC2_IP"
"@

$scriptPath = Join-Path $env:TEMP "deploy-frontend-ec2.sh"
$deployScript | Out-File -FilePath $scriptPath -Encoding utf8 -Force

Write-Host "✅ Script criado: $scriptPath" -ForegroundColor Green
Write-Host ""

# 5. Instruções para executar
Write-Host "5. INSTRUÇÕES PARA DEPLOY:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Opção A: Via AWS Systems Manager (Recomendado)" -ForegroundColor Yellow
Write-Host "   Execute no PowerShell:" -ForegroundColor Gray
Write-Host "   aws ssm send-command \`" -ForegroundColor White
Write-Host "       --instance-ids $INSTANCE_ID \`" -ForegroundColor White
Write-Host "       --document-name 'AWS-RunShellScript' \`" -ForegroundColor White
Write-Host "       --parameters 'commands=[`"bash -s`"]' \`" -ForegroundColor White
Write-Host "       --region $AWS_REGION" -ForegroundColor White
Write-Host ""

Write-Host "Opção B: Via SSH (se tiver chave SSH configurada)" -ForegroundColor Yellow
Write-Host "   1. Copie o script para o EC2:" -ForegroundColor Gray
Write-Host "      scp $scriptPath ec2-user@$EC2_IP:/tmp/deploy-frontend.sh" -ForegroundColor White
Write-Host ""
Write-Host "   2. Conecte-se ao EC2:" -ForegroundColor Gray
Write-Host "      ssh ec2-user@$EC2_IP" -ForegroundColor White
Write-Host ""
Write-Host "   3. Execute o script:" -ForegroundColor Gray
Write-Host "      chmod +x /tmp/deploy-frontend.sh" -ForegroundColor White
Write-Host "      /tmp/deploy-frontend.sh" -ForegroundColor White
Write-Host ""

Write-Host "Opção C: Executar comandos manualmente via SSM" -ForegroundColor Yellow
Write-Host "   Execute este comando para verificar se Docker está rodando:" -ForegroundColor Gray
Write-Host "   aws ssm start-session --target $INSTANCE_ID --region $AWS_REGION" -ForegroundColor White
Write-Host ""

# 6. Verificar se há container rodando
Write-Host "6. Verificando containers Docker no EC2..." -ForegroundColor Yellow
Write-Host "   (Isso requer SSM configurado)" -ForegroundColor Gray

$checkDocker = @"
#!/bin/bash
if command -v docker &> /dev/null; then
    echo "Docker instalado"
    sudo docker ps -a | grep frontend || echo "Nenhum container frontend encontrado"
else
    echo "Docker não instalado"
fi
"@

Write-Host ""
Write-Host "=== Resumo ===" -ForegroundColor Green
Write-Host "   EC2 IP: $EC2_IP" -ForegroundColor Cyan
Write-Host "   Instance ID: $INSTANCE_ID" -ForegroundColor Cyan
Write-Host "   ECR URL: $ECR_FRONTEND_URL" -ForegroundColor Cyan
Write-Host "   Script criado: $scriptPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Para executar o deploy automaticamente, use a Opção A acima" -ForegroundColor Yellow

