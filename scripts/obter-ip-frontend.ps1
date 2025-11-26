# Script para obter o IP atual do frontend ECS
# Uso: .\obter-ip-frontend.ps1

param(
    [string]$AWS_REGION = "sa-east-1"
)

Write-Host "=== Obtendo IP do Frontend ECS ===" -ForegroundColor Green
Write-Host ""

# Obter o diretório do script e encontrar o diretório infra
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$infraDir = Join-Path $projectRoot "infra"

# Verificar se o diretório infra existe
if (-not (Test-Path $infraDir)) {
    Write-Host "❌ ERRO: Diretório 'infra' não encontrado em: $infraDir" -ForegroundColor Red
    exit 1
}

# Obter Cluster ID
Push-Location $infraDir
try {
    $output = terraform output -raw ecs_cluster_id 2>&1 | Out-String
    if ($output -match "Warning|Error|No outputs found") {
        throw "Terraform output não disponível"
    }
    $CLUSTER_ID = $output.Trim().Trim('"')
    
    if ([string]::IsNullOrEmpty($CLUSTER_ID)) {
        throw "Cluster ID vazio"
    }
} catch {
    Write-Host "⚠️ Não foi possível obter Cluster ID do Terraform" -ForegroundColor Yellow
    Write-Host "   Tente executar 'terraform apply' primeiro" -ForegroundColor Yellow
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

Write-Host "Cluster ID: $CLUSTER_ID" -ForegroundColor Cyan
Write-Host "Aguardando tasks iniciarem..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Listar tasks
Write-Host "1. Listando tasks do frontend..." -ForegroundColor Yellow
$TASK_ARN = aws ecs list-tasks `
    --cluster $CLUSTER_ID `
    --service-name frontend-service `
    --region $AWS_REGION `
    --query 'taskArns[0]' `
    --output text

if ([string]::IsNullOrEmpty($TASK_ARN) -or $TASK_ARN -eq "None") {
    Write-Host "❌ ERRO: Nenhuma task encontrada para o serviço 'frontend-service'" -ForegroundColor Red
    Write-Host "   Verifique se o serviço está rodando:" -ForegroundColor Yellow
    Write-Host "   aws ecs describe-services --cluster $CLUSTER_ID --services frontend-service --region $AWS_REGION" -ForegroundColor Gray
    exit 1
}

Write-Host "   Task ARN: $TASK_ARN" -ForegroundColor Gray

# Obter ENI ID
Write-Host "2. Obtendo Network Interface..." -ForegroundColor Yellow
$ENI_ID = aws ecs describe-tasks `
    --cluster $CLUSTER_ID `
    --tasks $TASK_ARN `
    --region $AWS_REGION `
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' `
    --output text

if ([string]::IsNullOrEmpty($ENI_ID)) {
    Write-Host "❌ ERRO: Não foi possível obter Network Interface ID" -ForegroundColor Red
    Write-Host "   A task pode ainda estar inicializando. Aguarde alguns segundos e tente novamente." -ForegroundColor Yellow
    exit 1
}

Write-Host "   ENI ID: $ENI_ID" -ForegroundColor Gray

# Obter IP
Write-Host "3. Obtendo IP público..." -ForegroundColor Yellow
$FRONTEND_IP = aws ec2 describe-network-interfaces `
    --network-interface-ids $ENI_ID `
    --region $AWS_REGION `
    --query 'NetworkInterfaces[0].Association.PublicIp' `
    --output text

if ([string]::IsNullOrEmpty($FRONTEND_IP) -or $FRONTEND_IP -eq "None") {
    Write-Host "❌ ERRO: Não foi possível obter IP público" -ForegroundColor Red
    Write-Host "   A Network Interface pode ainda não ter recebido um IP público." -ForegroundColor Yellow
    Write-Host "   Aguarde alguns segundos e tente novamente." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== IP DO FRONTEND ===" -ForegroundColor Green
Write-Host "   URL: http://$FRONTEND_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️ IMPORTANTE: Este IP muda a cada deploy!" -ForegroundColor Yellow
Write-Host "   Execute este script novamente após cada deploy para obter o IP atual." -ForegroundColor Gray
Write-Host ""

