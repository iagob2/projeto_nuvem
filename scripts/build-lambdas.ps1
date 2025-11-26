# Script para buildar todas as Lambdas (criar ZIPs)
# Uso: .\build-lambdas.ps1

Write-Host "=== Buildando Lambdas ===" -ForegroundColor Green
Write-Host ""

# Obter diretório do script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$lambdaDir = Join-Path $projectRoot "lambda"
$buildDir = Join-Path $projectRoot "build"

# Criar diretório build se não existir
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    Write-Host "[OK] Diretorio 'build' criado" -ForegroundColor Green
}

# Lista de Lambdas para buildar
$lambdas = @(
    "criar_task",
    "listar_tasks",
    "obter_task_por_id",
    "salvar_csv",
    "atualizar_task",
    "deletar_task"
)

foreach ($lambda in $lambdas) {
    $lambdaPath = Join-Path $lambdaDir $lambda
    $zipPath = Join-Path $buildDir "$lambda.zip"
    
    Write-Host "[BUILD] Buildando $lambda..." -ForegroundColor Yellow
    
    if (-not (Test-Path $lambdaPath)) {
        Write-Host "[AVISO] Diretorio nao encontrado: $lambdaPath" -ForegroundColor Yellow
        continue
    }
    
    # Navegar para o diretório da Lambda
    Push-Location $lambdaPath
    
    try {
        # Verificar se package.json existe
        if (-not (Test-Path "package.json")) {
            Write-Host "[AVISO] package.json nao encontrado em $lambda" -ForegroundColor Yellow
            continue
        }
        
        # Instalar dependências
        Write-Host "   Instalando dependencias..." -ForegroundColor Gray
        npm install --production 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERRO] Erro ao instalar dependencias para $lambda" -ForegroundColor Red
            continue
        }
        
        # Criar ZIP (incluir tudo exceto node_modules/.cache e arquivos temporários)
        Write-Host "   Criando ZIP..." -ForegroundColor Gray
        
        # Lista de arquivos para incluir
        $filesToZip = @()
        $filesToZip += Get-ChildItem -Path . -File -Recurse | Where-Object {
            $_.FullName -notmatch "node_modules" -or $_.FullName -match "node_modules[\\/][^\\/]+$"
        }
        
        # Criar ZIP usando Compress-Archive
        # Primeiro, copiar arquivos necessários para um diretório temporário
        $tempDir = Join-Path $env:TEMP "lambda-build-$lambda-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            # Copiar index.js e package.json
            Copy-Item -Path "index.js" -Destination $tempDir -ErrorAction SilentlyContinue
            Copy-Item -Path "package.json" -Destination $tempDir -ErrorAction SilentlyContinue
            
            # Copiar node_modules (apenas produção)
            if (Test-Path "node_modules") {
                Copy-Item -Path "node_modules" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Criar ZIP
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
            
            $zipSizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 2)
            Write-Host "[OK] $lambda.zip criado ($zipSizeKB KB)" -ForegroundColor Green
        } finally {
            # Limpar diretório temporário
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-Host "[ERRO] Erro ao buildar $lambda : $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

Write-Host "=== Build concluido! ===" -ForegroundColor Green
Write-Host ""
Write-Host "ZIPs criados em: $buildDir" -ForegroundColor Cyan

