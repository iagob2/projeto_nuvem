# Script para fazer deploy apenas do Front-end
# Uso: .\deploy-frontend.ps1

param(
    [string]$AWS_REGION = "sa-east-1"
)

$ErrorActionPreference = "Stop"

# Obter diretório do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$infraDir = Join-Path $projectRoot "infra"
$frontendDir = Join-Path $projectRoot "front-end"

Write-Host "=== Deploy do Front-end ===" -ForegroundColor Green
Write-Host "   Regiao: $AWS_REGION" -ForegroundColor Gray
Write-Host ""

# Funções auxiliares
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "[AVISO] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERRO] $msg" -ForegroundColor Red }

# 1. Verificar pré-requisitos
Write-Info "Verificando pre-requisitos..."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker nao encontrado! Instale o Docker Desktop."
    exit 1
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI nao encontrado! Instale o AWS CLI."
    exit 1
}
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform nao encontrado! Instale o Terraform."
    exit 1
}
Write-Success "Pre-requisitos OK"
Write-Host ""

# 2. Obter URLs do Terraform
Write-Info "Obtendo URLs do API Gateway e ECR..."
Push-Location $infraDir

try {
    # Obter API Gateway URL
    $apiOutput = terraform output -raw api_gateway_invoke_url 2>&1
    if ($apiOutput -is [System.Array]) {
        $apiOutput = $apiOutput -join "`n"
    }
    $API_GATEWAY_URL = $apiOutput.ToString().Trim().Trim('"').Trim()
    
    # Obter ECR Frontend URL
    $ecrOutput = terraform output -raw ecr_frontend_repository_url 2>&1
    if ($ecrOutput -is [System.Array]) {
        $ecrOutput = $ecrOutput -join "`n"
    }
    $ECR_FRONTEND_URL = $ecrOutput.ToString().Trim().Trim('"').Trim()
    
    # Obter Cluster ID
    $clusterOutput = terraform output -raw ecs_cluster_id 2>&1
    if ($clusterOutput -is [System.Array]) {
        $clusterOutput = $clusterOutput -join "`n"
    }
    $CLUSTER_ID = $clusterOutput.ToString().Trim().Trim('"').Trim()
    
    # Verificar se as variáveis foram obtidas corretamente
    if ([string]::IsNullOrEmpty($API_GATEWAY_URL) -or $API_GATEWAY_URL -match "Error|Warning|No outputs") {
        Write-Host "[DEBUG] Output bruto API Gateway: $apiOutput" -ForegroundColor Yellow
        throw "Nao foi possivel obter API Gateway URL"
    }
    if ([string]::IsNullOrEmpty($ECR_FRONTEND_URL) -or $ECR_FRONTEND_URL -match "Error|Warning|No outputs") {
        Write-Host "[DEBUG] Output bruto ECR Frontend: $ecrOutput" -ForegroundColor Yellow
        throw "Nao foi possivel obter ECR Frontend URL"
    }
    if ([string]::IsNullOrEmpty($CLUSTER_ID) -or $CLUSTER_ID -match "Error|Warning|No outputs") {
        Write-Host "[DEBUG] Output bruto Cluster ID: $clusterOutput" -ForegroundColor Yellow
        throw "Nao foi possivel obter Cluster ID"
    }
    
    Write-Success "URLs obtidas:"
    Write-Host "   API Gateway: $API_GATEWAY_URL" -ForegroundColor Gray
    Write-Host "   ECR Frontend: $ECR_FRONTEND_URL" -ForegroundColor Gray
    Write-Host "   Cluster ID: $CLUSTER_ID" -ForegroundColor Gray
    
    # Verificar se ECR_FRONTEND_URL está realmente preenchida antes de continuar
    if ([string]::IsNullOrWhiteSpace($ECR_FRONTEND_URL)) {
        throw "ECR_FRONTEND_URL esta vazia apos processamento"
    }
} catch {
    Write-Error "Falha ao obter URLs do Terraform: $_"
    Write-Warning "Certifique-se de que o Terraform foi aplicado e os outputs estao disponiveis"
    Write-Host ""
    Write-Host "Tente executar manualmente:" -ForegroundColor Yellow
    Write-Host "   cd infra" -ForegroundColor Gray
    Write-Host "   terraform output ecr_frontend_repository_url" -ForegroundColor Gray
    Pop-Location
    exit 1
} finally {
    Pop-Location
}
Write-Host ""

# 3. Preparar front-end
Write-Info "Preparando Front-end..."
Push-Location $frontendDir

# Verificar se diretório public existe
if (-not (Test-Path "public")) {
    New-Item -ItemType Directory -Path "public" -Force | Out-Null
    Write-Info "Diretorio 'public' criado"
}

# Gerar config.js com URL do API Gateway
Write-Info "Gerando config.js..."
$configContent = @"
window.APP_CONFIG = {
  API_URL: '$API_GATEWAY_URL'
};
"@
$configContent | Out-File -FilePath "public\config.js" -Encoding utf8
Write-Info "config.js criado com API_URL: $API_GATEWAY_URL"
Write-Host ""

# 4. Build da imagem Docker
Write-Info "Buildando imagem Docker do Front-end..."
docker build -t frontend-nuvem:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao buildar imagem do frontend!"
    Pop-Location
    exit 1
}
Write-Success "Imagem Docker buildada com sucesso"
Write-Host ""

# 5. Autenticar no ECR
Write-Info "Autenticando no ECR..."
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao autenticar no ECR!"
    Pop-Location
    exit 1
}
Write-Success "Autenticado no ECR"
Write-Host ""

# 6. Tag e Push para ECR
Write-Info "Fazendo tag e push da imagem..."

# Verificar se a variável está preenchida
if ([string]::IsNullOrWhiteSpace($ECR_FRONTEND_URL)) {
    Write-Error "ECR_FRONTEND_URL esta vazia! Nao e possivel fazer tag e push."
    Write-Host "   Tentando obter novamente..." -ForegroundColor Yellow
    
    # Tentar obter novamente
    Push-Location $infraDir
    $ecrOutput = terraform output -raw ecr_frontend_repository_url 2>&1
    if ($ecrOutput -is [System.Array]) {
        $ecrOutput = $ecrOutput -join "`n"
    }
    $ECR_FRONTEND_URL = $ecrOutput.ToString().Trim().Trim('"').Trim()
    Pop-Location
    
    if ([string]::IsNullOrWhiteSpace($ECR_FRONTEND_URL)) {
        Write-Error "Nao foi possivel obter ECR_FRONTEND_URL. Execute manualmente:"
        Write-Host "   cd infra" -ForegroundColor Gray
        Write-Host "   terraform output ecr_frontend_repository_url" -ForegroundColor Gray
        Pop-Location
        exit 1
    }
}

$targetImage = "${ECR_FRONTEND_URL}:latest"
Write-Host "   Tagging: frontend-nuvem:latest -> $targetImage" -ForegroundColor Gray

docker tag frontend-nuvem:latest $targetImage
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao fazer tag da imagem!"
    Write-Host "   Comando: docker tag frontend-nuvem:latest $targetImage" -ForegroundColor Yellow
    Pop-Location
    exit 1
}

Write-Host "   Pushing: $targetImage" -ForegroundColor Gray
docker push $targetImage
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao fazer push da imagem do frontend!"
    Write-Host "   Comando: docker push $targetImage" -ForegroundColor Yellow
    Pop-Location
    exit 1
}
Write-Success "Imagem enviada para ECR"
Pop-Location
Write-Host ""

# 7. Atualizar serviço ECS
Write-Info "Atualizando servico ECS frontend-service..."
aws ecs update-service `
    --cluster $CLUSTER_ID `
    --service frontend-service `
    --force-new-deployment `
    --region $AWS_REGION `
    | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao atualizar servico ECS!"
    exit 1
}
Write-Success "Servico ECS atualizado (novo deployment iniciado)"
Write-Host ""

# 8. Aguardar serviço iniciar
Write-Info "Aguardando servico iniciar (60 segundos)..."
Start-Sleep -Seconds 60

# 9. Verificar status
Write-Info "Verificando status do servico..."
$frontendStatus = aws ecs describe-services `
    --cluster $CLUSTER_ID `
    --services frontend-service `
    --region $AWS_REGION `
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition}}' `
    --output json | ConvertFrom-Json

Write-Host "Status do Frontend Service:" -ForegroundColor Cyan
Write-Host "   Status: $($frontendStatus.Status)" -ForegroundColor Gray
Write-Host "   Running: $($frontendStatus.Running)" -ForegroundColor Gray
Write-Host "   Desired: $($frontendStatus.Desired)" -ForegroundColor Gray
Write-Host ""

# 10. Obter IP do frontend
Write-Info "Obtendo IP publico do Front-end..."
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
Write-Host "=== Deploy do Front-end concluido! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Resumo:" -ForegroundColor Cyan
Write-Host "   API Gateway: $API_GATEWAY_URL" -ForegroundColor Gray
if ($frontendIP) {
    Write-Host "   Front-end URL: http://$frontendIP" -ForegroundColor Green
} else {
    Write-Host "   Front-end URL: (aguardando IP ser atribuido)" -ForegroundColor Yellow
    Write-Host "   Execute: .\obter-ip-frontend.ps1 para obter o IP atual" -ForegroundColor Gray
}
Write-Host "   ECR Front-end: $ECR_FRONTEND_URL" -ForegroundColor Gray
Write-Host ""
Write-Host "Para verificar o status:" -ForegroundColor Yellow
Write-Host "   aws ecs describe-services --cluster $CLUSTER_ID --services frontend-service --region $AWS_REGION" -ForegroundColor Gray
Write-Host ""
Write-Host "Para obter o IP atual:" -ForegroundColor Yellow
Write-Host "   cd scripts; .\obter-ip-frontend.ps1" -ForegroundColor Gray
Write-Host ""

