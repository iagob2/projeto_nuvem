# Script para importar repositórios ECR existentes no Terraform
# Execute este script se os repositórios ECR já existirem na AWS
# Uso: .\import-ecr.ps1

Write-Host "=== Importando repositórios ECR existentes ===" -ForegroundColor Green
Write-Host ""

$AWS_REGION = "sa-east-1"

# Verificar se os repositórios existem
Write-Host "Verificando repositórios ECR existentes..." -ForegroundColor Yellow

$backendExists = aws ecr describe-repositories --repository-names back-end-nuvem --region $AWS_REGION 2>$null
$frontendExists = aws ecr describe-repositories --repository-names frontend-nuvem --region $AWS_REGION 2>$null

if ($LASTEXITCODE -eq 0 -and $backendExists) {
    Write-Host "✅ Repositório 'back-end-nuvem' encontrado" -ForegroundColor Green
    Write-Host "Importando 'back-end-nuvem'..." -ForegroundColor Yellow
    terraform import aws_ecr_repository.backend back-end-nuvem
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 'back-end-nuvem' importado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Erro ao importar 'back-end-nuvem'. Pode já estar no estado." -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ Repositório 'back-end-nuvem' não existe ou será criado pelo Terraform" -ForegroundColor Cyan
}

Write-Host ""

if ($LASTEXITCODE -eq 0 -and $frontendExists) {
    Write-Host "✅ Repositório 'frontend-nuvem' encontrado" -ForegroundColor Green
    Write-Host "Importando 'frontend-nuvem'..." -ForegroundColor Yellow
    terraform import aws_ecr_repository.frontend frontend-nuvem
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 'frontend-nuvem' importado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Erro ao importar 'frontend-nuvem'. Pode já estar no estado." -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ Repositório 'frontend-nuvem' não existe ou será criado pelo Terraform" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Concluído! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Agora você pode executar:" -ForegroundColor Cyan
Write-Host "  terraform plan" -ForegroundColor Gray
Write-Host "  terraform apply" -ForegroundColor Gray

