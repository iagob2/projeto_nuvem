# Script para RESET COMPLETO - Destruir tudo e começar do zero
# ATENCAO: Este script vai DESTRUIR todos os recursos da AWS criados pelo Terraform!

Write-Host "========================================" -ForegroundColor Red
Write-Host "  RESET COMPLETO - DESTRUIR TUDO" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

Write-Host "ATENCAO: Este script vai DESTRUIR TODOS os recursos!" -ForegroundColor Red
Write-Host ""
Write-Host "Recursos que serao destruidos:" -ForegroundColor Yellow
Write-Host "  - VPC, Subnets, NAT Gateways, Internet Gateway" -ForegroundColor White
Write-Host "  - RDS MySQL Database" -ForegroundColor White
Write-Host "  - Lambda Functions (4 functions)" -ForegroundColor White
Write-Host "  - API Gateway" -ForegroundColor White
Write-Host "  - ECS Cluster e Services" -ForegroundColor White
Write-Host "  - ECR Repositories" -ForegroundColor White
Write-Host "  - S3 Buckets" -ForegroundColor White
Write-Host "  - Security Groups" -ForegroundColor White
Write-Host "  - Secrets Manager Secrets" -ForegroundColor White
Write-Host "  - EC2 Instances" -ForegroundColor White
Write-Host "  - IAM Roles e Policies" -ForegroundColor White
Write-Host "  - CloudWatch Log Groups" -ForegroundColor White
Write-Host ""
Write-Host "ISSO E IRREVERSIVEL!" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Digite 'DESTRUIR' para confirmar que deseja destruir tudo"

if ($confirm -ne "DESTRUIR") {
    Write-Host ""
    Write-Host "Operacao cancelada." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "=== INICIANDO RESET COMPLETO ===" -ForegroundColor Yellow
Write-Host ""

# Obter diretório do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projetoRoot = Split-Path -Parent $scriptDir
$infraDir = Join-Path $projetoRoot "infra"

if (-not (Test-Path $infraDir)) {
    Write-Host "❌ ERRO: Diretório 'infra' não encontrado!" -ForegroundColor Red
    exit 1
}

Push-Location $infraDir

try {
    # 1. Remover locks do Terraform
    Write-Host "1. Removendo locks do Terraform..." -ForegroundColor Cyan
    $locks = aws dynamodb scan --table-name terraform-locks --region sa-east-1 --query 'Items[].LockID.S' --output text 2>$null
    
    if ($locks) {
        $lockIds = $locks -split "`t"
        foreach ($lockId in $lockIds) {
            if ($lockId -and $lockId -ne "") {
                Write-Host "   Removendo lock: $lockId" -ForegroundColor Gray
                terraform force-unlock -force $lockId 2>&1 | Out-Null
            }
        }
    }
    Write-Host "   ✅ Locks removidos" -ForegroundColor Green
    Write-Host ""
    
    # 2. Remover secrets do Secrets Manager que podem estar bloqueando
    Write-Host "2. Verificando Secrets Manager..." -ForegroundColor Cyan
    $secrets = aws secretsmanager list-secrets --region sa-east-1 --query 'SecretList[?contains(Name, `nuvem`) || contains(Name, `tasks`)].Name' --output text 2>$null
    
    if ($secrets) {
        $secretNames = $secrets -split "`t"
        foreach ($secretName in $secretNames) {
            if ($secretName -and $secretName -ne "") {
                Write-Host "   Removendo secret: $secretName" -ForegroundColor Gray
                # Forçar remoção imediata
                aws secretsmanager delete-secret --secret-id $secretName --force-delete-without-recovery --region sa-east-1 2>&1 | Out-Null
            }
        }
    }
    Write-Host "   ✅ Secrets removidos" -ForegroundColor Green
    Write-Host ""
    
    # 3. Executar terraform destroy
    Write-Host "3. Executando terraform destroy..." -ForegroundColor Cyan
    Write-Host "   Isso pode levar varios minutos..." -ForegroundColor Yellow
    Write-Host ""
    
    terraform destroy -auto-approve
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Todos os recursos foram destruidos com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "=== RESET COMPLETO CONCLUIDO ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Proximos passos para recriar tudo:" -ForegroundColor Cyan
        Write-Host "  1. cd infra" -ForegroundColor White
        Write-Host "  2. terraform init" -ForegroundColor White
        Write-Host "  3. terraform plan" -ForegroundColor White
        Write-Host "  4. terraform apply" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "⚠️ Erro ao destruir alguns recursos." -ForegroundColor Yellow
        Write-Host "   Verifique os erros acima." -ForegroundColor White
        Write-Host "   Alguns recursos podem precisar ser removidos manualmente via AWS Console." -ForegroundColor Yellow
        Write-Host ""
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ ERRO durante o reset: $_" -ForegroundColor Red
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== FIM DO RESET ===" -ForegroundColor Yellow

