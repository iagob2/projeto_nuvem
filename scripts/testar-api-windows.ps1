# Script para testar a API no Windows PowerShell
# Uso: .\testar-api-windows.ps1

Write-Host "=== Testando API Gateway ===" -ForegroundColor Green
Write-Host ""

# Obter o diretório do script e encontrar o diretório infra
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$infraDir = Join-Path (Split-Path -Parent $scriptDir) "infra"

# Verificar se o diretório infra existe
if (-not (Test-Path $infraDir)) {
    Write-Host "❌ ERRO: Diretório 'infra' não encontrado em: $infraDir" -ForegroundColor Red
    Write-Host "   Execute este script do diretório 'scripts' ou defina a URL manualmente" -ForegroundColor Yellow
    exit 1
}

# 1. Obter URL do API Gateway
Write-Host "1. Obtendo URL do API Gateway..." -ForegroundColor Yellow
Push-Location $infraDir

try {
    $output = terraform output -raw api_gateway_invoke_url 2>&1 | Out-String
    
    if ($output -match "Warning|Error|No outputs found") {
        throw "Terraform output não disponível"
    }
    
    $API_GATEWAY_URL = $output.Trim().Trim('"')
    
    if ([string]::IsNullOrEmpty($API_GATEWAY_URL) -or $API_GATEWAY_URL -match "Warning|Error") {
        throw "URL vazia ou inválida"
    }
} catch {
    Write-Host "⚠️ Não foi possível obter URL do Terraform, usando URL padrão..." -ForegroundColor Yellow
    # URL padrão conhecida do projeto (atualizada)
    $API_GATEWAY_URL = "https://haxsg03g96.execute-api.sa-east-1.amazonaws.com/dev"
    Write-Host "   Usando: $API_GATEWAY_URL" -ForegroundColor Cyan
} finally {
    Pop-Location
}

Write-Host "✅ API Gateway URL: $API_GATEWAY_URL" -ForegroundColor Green
Write-Host ""

# 2. Testar GET /tasks
Write-Host "2. Testando GET /tasks..." -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method GET -ErrorAction Stop
    Write-Host "✅ Sucesso! Tasks encontradas:" -ForegroundColor Green
    $result | ConvertTo-Json -Depth 5
} catch {
    Write-Host "❌ ERRO ao buscar tasks:" -ForegroundColor Red
    $errorMsg = $_.Exception.Message
    Write-Host "   Erro: $errorMsg" -ForegroundColor Yellow
    
    # Tentar obter resposta do servidor se disponível
    if ($_.Exception.Response) {
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            if ($responseStream) {
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                Write-Host "   Resposta do servidor: $responseBody" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   Não foi possível ler resposta do servidor" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "💡 Possíveis causas:" -ForegroundColor Cyan
    Write-Host "   1. Tabela 'tasks' não existe no banco de dados" -ForegroundColor White
    Write-Host "   2. Lambda com erro (verifique logs no CloudWatch)" -ForegroundColor White
    Write-Host "   3. API Gateway não configurado corretamente" -ForegroundColor White
}
Write-Host ""

# 3. Testar POST /tasks
Write-Host "3. Testando POST /tasks..." -ForegroundColor Yellow
$body = @{
    title = "Teste via PowerShell Windows"
    description = "Teste criado em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    status = "pending"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "✅ Task criada com sucesso!" -ForegroundColor Green
    $result | ConvertTo-Json -Depth 5
} catch {
    Write-Host "❌ ERRO ao criar task:" -ForegroundColor Red
    $errorMsg = $_.Exception.Message
    Write-Host "   Erro: $errorMsg" -ForegroundColor Yellow
    
    # Tentar obter resposta do servidor se disponível
    if ($_.Exception.Response) {
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            if ($responseStream) {
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                Write-Host "   Resposta do servidor: $responseBody" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   Não foi possível ler resposta do servidor" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# 4. Listar tasks novamente
Write-Host "4. Listando tasks novamente para verificar a nova task..." -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method GET -ErrorAction Stop
    Write-Host "✅ Total de tasks: $($result.count)" -ForegroundColor Green
    if ($result.tasks) {
        Write-Host "   Últimas tasks:" -ForegroundColor Cyan
        $result.tasks | Select-Object -First 3 | ForEach-Object {
            Write-Host "   - $($_.title) (ID: $($_.id), Status: $($_.status))" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "❌ ERRO: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Teste concluído ===" -ForegroundColor Green
