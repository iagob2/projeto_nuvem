# Script de Deploy Completo - Windows PowerShell
# Projeto Nuvem - Containerizar e Enviar para AWS
# Baseado no GUIA_COMPLETO_DEPLOY.md

param(
    [string]$AWS_REGION = "sa-east-1"
)

$ErrorActionPreference = "Stop"

# Obter diretório do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "🚀 Iniciando deploy completo do Projeto Nuvem..." -ForegroundColor Cyan
Write-Host "   Região: $AWS_REGION" -ForegroundColor Gray
Write-Host "   Diretório do projeto: $projectRoot" -ForegroundColor Gray
Write-Host ""

# Cores
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "📋 $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }

# 1. Verificar pré-requisitos
Write-Info "Passo 1/9: Verificando pré-requisitos..."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker não encontrado! Instale o Docker Desktop."
    exit 1
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI não encontrado! Instale o AWS CLI."
    exit 1
}
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform não encontrado! Instale o Terraform."
    exit 1
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Warning "npm não encontrado! Será necessário para criar a tabela no banco."
}
Write-Success "Pré-requisitos OK"
Write-Host ""

# 2. Verificar estrutura do projeto
Write-Info "Passo 2/9: Verificando estrutura do projeto..."
$infraDir = Join-Path $projectRoot "infra"
$backendDir = Join-Path $projectRoot "back-end"
$frontendDir = Join-Path $projectRoot "front-end"

if (-not (Test-Path $infraDir)) {
    Write-Error "Diretório 'infra' não encontrado em: $infraDir"
    exit 1
}
if (-not (Test-Path $backendDir)) {
    Write-Error "Diretório 'back-end' não encontrado em: $backendDir"
    exit 1
}
if (-not (Test-Path $frontendDir)) {
    Write-Error "Diretório 'front-end' não encontrado em: $frontendDir"
    Write-Error "   A pasta front-end deve estar em: $frontendDir"
    exit 1
}
Write-Success "Estrutura do projeto OK"
Write-Host ""

# 3. Verificar/Importar ECR se necessário
Write-Info "Passo 3/9: Verificando repositórios ECR existentes..."
Push-Location $infraDir

# Verificar se os repositórios ECR já existem
$backendRepoExists = $false
$frontendRepoExists = $false

try {
    $backendCheck = aws ecr describe-repositories --repository-names back-end-nuvem --region $AWS_REGION 2>$null
    if ($LASTEXITCODE -eq 0) {
        $backendRepoExists = $true
        Write-Warning "Repositório 'back-end-nuvem' já existe na AWS"
    }
} catch {
    # Repositório não existe, será criado
}

try {
    $frontendCheck = aws ecr describe-repositories --repository-names frontend-nuvem --region $AWS_REGION 2>$null
    if ($LASTEXITCODE -eq 0) {
        $frontendRepoExists = $true
        Write-Warning "Repositório 'frontend-nuvem' já existe na AWS"
    }
} catch {
    # Repositório não existe, será criado
}

# Se algum repositório existir, tentar importar
if ($backendRepoExists -or $frontendRepoExists) {
    Write-Info "Tentando importar repositórios ECR existentes..."
    if (Test-Path "import-ecr.ps1") {
        try {
            & ".\import-ecr.ps1"
            Write-Success "Importação de ECR concluída"
        } catch {
            Write-Warning "Erro ao importar ECR (pode já estar no estado): $_"
        }
    } else {
        Write-Warning "Script import-ecr.ps1 não encontrado. Continuando..."
    }
} else {
    Write-Info "Repositórios ECR serão criados pelo Terraform"
}
Write-Host ""

# 4. Inicializar Terraform
Write-Info "Passo 4/9: Inicializando Terraform..."
if (-not (Test-Path ".terraform")) {
    Write-Info "Executando terraform init..."
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha ao inicializar Terraform!"
        Pop-Location
        exit 1
    }
} else {
    Write-Info "Terraform já inicializado"
}
Write-Host ""

# 5. Deploy da infraestrutura
Write-Info "Passo 5/9: Deployando infraestrutura com Terraform..."
Write-Info "   Isso pode levar 10-15 minutos (principalmente o RDS)..."
Write-Host ""

terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao criar plano do Terraform!"
    Pop-Location
    exit 1
}

terraform apply -auto-approve tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao aplicar infraestrutura!"
    Pop-Location
    exit 1
}

Write-Success "Infraestrutura deployada"
Write-Host ""

# 6. Obter URLs dos outputs
Write-Info "Passo 6/9: Obtendo URLs dos recursos criados..."
try {
    $API_GATEWAY_URL = (terraform output -raw api_gateway_invoke_url).Trim().Trim('"')
    $ECR_BACKEND_URL = (terraform output -raw ecr_backend_repository_url).Trim()
    $ECR_FRONTEND_URL = (terraform output -raw ecr_frontend_repository_url).Trim()
    $CLUSTER_ID = (terraform output -raw ecs_cluster_id).Trim()
    
    Write-Success "URLs obtidas:"
    Write-Host "   API Gateway: $API_GATEWAY_URL" -ForegroundColor Gray
    Write-Host "   ECR Back-end: $ECR_BACKEND_URL" -ForegroundColor Gray
    Write-Host "   ECR Front-end: $ECR_FRONTEND_URL" -ForegroundColor Gray
    Write-Host "   Cluster ID: $CLUSTER_ID" -ForegroundColor Gray
} catch {
    Write-Error "Falha ao obter outputs do Terraform: $_"
    Pop-Location
    exit 1
}
Write-Host ""

# 7. Criar tabela no banco de dados
Write-Info "Passo 7/9: Criando tabela 'tasks' no banco de dados..."
if (Test-Path "init-database.ps1") {
    try {
        Write-Info "Executando init-database.ps1..."
        & ".\init-database.ps1" -AWS_REGION $AWS_REGION
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tabela criada com sucesso!"
        } else {
            Write-Warning "Script init-database.ps1 retornou código de erro. Verifique os logs acima."
            Write-Warning "Você pode executar manualmente: cd infra; .\init-database.ps1"
        }
    } catch {
        Write-Warning "Erro ao executar init-database.ps1: $_"
        Write-Warning "Execute manualmente: cd infra; .\init-database.ps1"
    }
} else {
    Write-Warning "Script init-database.ps1 não encontrado!"
    Write-Warning "Execute manualmente: cd infra; .\init-database.ps1"
}
Write-Host ""

Pop-Location

# 8. Build e push do Back-end
Write-Info "Passo 8/9: Buildando e enviando imagem do Back-end..."
Push-Location $backendDir

Write-Info "Buildando imagem Docker..."
docker build -t back-end-nuvem:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao buildar imagem do backend!"
    Pop-Location
    exit 1
}

Write-Info "Autenticando no ECR..."
# Método que funciona no Windows PowerShell
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao autenticar no ECR!"
    Pop-Location
    exit 1
}

Write-Info "Fazendo tag e push..."
docker tag back-end-nuvem:latest "$ECR_BACKEND_URL:latest"
docker push "$ECR_BACKEND_URL:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao fazer push da imagem do backend!"
    Pop-Location
    exit 1
}

Write-Success "Back-end enviado para ECR"
Pop-Location
Write-Host ""

# 9. Build e push do Front-end
Write-Info "Passo 9/9: Preparando e enviando Front-end..."
Push-Location $frontendDir

# Verificar se diretório public existe
if (-not (Test-Path "public")) {
    New-Item -ItemType Directory -Path "public" -Force | Out-Null
}

# Gerar config.js com URL do API Gateway
Write-Info "Gerando config.js..."
$configContent = @"
window.APP_CONFIG = {
  API_URL: '$API_GATEWAY_URL'
};
"@
$configContent | Out-File -FilePath "public\config.js" -Encoding utf8
Write-Info "   config.js criado com API_URL: $API_GATEWAY_URL"

Write-Info "Buildando imagem Docker..."
docker build -t frontend-nuvem:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao buildar imagem do frontend!"
    Pop-Location
    exit 1
}

Write-Info "Autenticando no ECR..."
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao autenticar no ECR!"
    Pop-Location
    exit 1
}

Write-Info "Fazendo tag e push..."
docker tag frontend-nuvem:latest "$ECR_FRONTEND_URL:latest"
docker push "$ECR_FRONTEND_URL:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao fazer push da imagem do frontend!"
    Pop-Location
    exit 1
}

Write-Success "Front-end enviado para ECR"
Pop-Location
Write-Host ""

# 10. Atualizar serviços ECS
Write-Info "Atualizando serviços ECS para usar as novas imagens..."
aws ecs update-service `
    --cluster $CLUSTER_ID `
    --service back-end-service `
    --force-new-deployment `
    --region $AWS_REGION `
    | Out-Null

aws ecs update-service `
    --cluster $CLUSTER_ID `
    --service frontend-service `
    --force-new-deployment `
    --region $AWS_REGION `
    | Out-Null

Write-Success "Serviços ECS atualizados"
Write-Host ""

# 11. Aguardar serviços iniciarem
Write-Info "Aguardando serviços iniciarem (60 segundos)..."
Start-Sleep -Seconds 60

# Verificar status dos serviços
Write-Info "Verificando status dos serviços..."
$backendStatus = aws ecs describe-services `
    --cluster $CLUSTER_ID `
    --services back-end-service `
    --region $AWS_REGION `
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' `
    --output table

$frontendStatus = aws ecs describe-services `
    --cluster $CLUSTER_ID `
    --services frontend-service `
    --region $AWS_REGION `
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' `
    --output table

Write-Host "Back-end Service:" -ForegroundColor Cyan
$backendStatus | Write-Host
Write-Host "Frontend Service:" -ForegroundColor Cyan
$frontendStatus | Write-Host
Write-Host ""

# 12. Obter IP do frontend
Write-Info "Obtendo IP público do Front-end..."
$taskArn = aws ecs list-tasks `
    --cluster $CLUSTER_ID `
    --service-name frontend-service `
    --region $AWS_REGION `
    --query 'taskArns[0]' `
    --output text

$frontendIP = $null
if ($taskArn -and $taskArn -ne "None") {
    $eniId = aws ecs describe-tasks `
        --cluster $CLUSTER_ID `
        --tasks $taskArn `
        --region $AWS_REGION `
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' `
        --output text
    
    if ($eniId) {
        $frontendIP = aws ec2 describe-network-interfaces `
            --network-interface-ids $eniId `
            --region $AWS_REGION `
            --query 'NetworkInterfaces[0].Association.PublicIp' `
            --output text
    }
}

# Resumo final
Write-Host ""
Write-Host "🎉 Deploy completo finalizado!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Resumo:" -ForegroundColor Cyan
Write-Host "   API Gateway: $API_GATEWAY_URL" -ForegroundColor Gray
if ($frontendIP) {
    Write-Host "   Front-end URL: http://$frontendIP" -ForegroundColor Green
} else {
    Write-Host "   Front-end URL: (aguardando IP ser atribuído)" -ForegroundColor Yellow
}
Write-Host "   ECR Back-end: $ECR_BACKEND_URL" -ForegroundColor Gray
Write-Host "   ECR Front-end: $ECR_FRONTEND_URL" -ForegroundColor Gray
Write-Host ""
Write-Host "🔍 Para verificar o status:" -ForegroundColor Yellow
Write-Host "   aws ecs describe-services --cluster $CLUSTER_ID --services back-end-service frontend-service --region $AWS_REGION" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 Para ver logs:" -ForegroundColor Yellow
Write-Host "   aws logs tail /ecs/nuvem --follow --region $AWS_REGION" -ForegroundColor Gray
Write-Host ""
Write-Host "🧪 Para testar a API:" -ForegroundColor Yellow
Write-Host "   cd scripts; .\testar-api-windows.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️ IMPORTANTE:" -ForegroundColor Yellow
Write-Host "   - O IP do frontend pode mudar a cada deploy" -ForegroundColor Gray
Write-Host "   - Use o script 'obter-ip-frontend.ps1' para obter o IP atual" -ForegroundColor Gray
Write-Host ""

