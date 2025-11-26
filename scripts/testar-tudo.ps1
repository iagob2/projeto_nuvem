# Script completo para testar toda a API
# Uso: .\testar-tudo.ps1

Write-Host "========================================" -ForegroundColor Green
Write-Host "  TESTE COMPLETO DA API" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
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

# 1. Obter URL do API Gateway via Terraform
Write-Host "Obtendo URL do API Gateway via Terraform..." -ForegroundColor Yellow
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

$erros = 0
$sucessos = 0

# Funcao para testar endpoint
function Testar-Endpoint {
    param(
        [string]$Metodo,
        [string]$Endpoint,
        [object]$Body = $null,
        [string]$Descricao
    )
    
    Write-Host "Testando: $Descricao..." -ForegroundColor Yellow
    Write-Host "   $Metodo $Endpoint" -ForegroundColor Gray
    
    try {
        $params = @{
            Uri = "$API_GATEWAY_URL$Endpoint"
            Method = $Metodo
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        Write-Host "   SUCESSO (Status: $($response.StatusCode))" -ForegroundColor Green
        
        if ($response.Content) {
            $jsonResponse = $response.Content | ConvertFrom-Json
            Write-Host "   Resposta:" -ForegroundColor Cyan
            $jsonResponse | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
        }
        
        $script:sucessos++
        return $true
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "N/A" }
        Write-Host "   ERRO (Status: $statusCode)" -ForegroundColor Red
        Write-Host "   Mensagem: $($_.Exception.Message)" -ForegroundColor Yellow
        
        # Tentar ler resposta de erro
        if ($_.Exception.Response) {
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
                $errorStream.Close()
                
                if ($errorBody) {
                    Write-Host "   Resposta do servidor: $errorBody" -ForegroundColor Yellow
                }
            } catch {
                # Ignorar erro ao ler stream
            }
        }
        
        $script:erros++
        return $false
    }
    Write-Host ""
}

# 1. Testar GET /tasks
Write-Host "1. TESTE: Listar Tasks (GET /tasks)" -ForegroundColor Cyan
$result1 = Testar-Endpoint -Metodo "GET" -Endpoint "/tasks" -Descricao "Listar todas as tasks"
Write-Host ""

# 2. Testar POST /tasks
Write-Host "2. TESTE: Criar Task (POST /tasks)" -ForegroundColor Cyan
$body = @{
    title = "Teste Automatizado PowerShell"
    description = "Teste criado em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    status = "pending"
}
$result2 = Testar-Endpoint -Metodo "POST" -Endpoint "/tasks" -Body $body -Descricao "Criar nova task"
Write-Host ""

# Se criou task, obter o ID para proximo teste
$taskId = $null
if ($result2) {
    try {
        $response = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method GET -ErrorAction Stop
        if ($response.tasks -and $response.tasks.Count -gt 0) {
            $taskId = $response.tasks[0].id
            Write-Host "   Task criada com ID: $taskId" -ForegroundColor Green
        }
    } catch {
        Write-Host "   Nao foi possivel obter ID da task criada" -ForegroundColor Yellow
    }
}

# 3. Testar GET /tasks/{id}
if ($taskId) {
    Write-Host "3. TESTE: Obter Task por ID (GET /tasks/$taskId)" -ForegroundColor Cyan
    $result3 = Testar-Endpoint -Metodo "GET" -Endpoint "/tasks/$taskId" -Descricao "Obter task por ID"
    Write-Host ""
} else {
    Write-Host "3. TESTE: Obter Task por ID (GET /tasks/1)" -ForegroundColor Cyan
    $result3 = Testar-Endpoint -Metodo "GET" -Endpoint "/tasks/1" -Descricao "Obter task por ID"
    Write-Host ""
}

# 4. Testar GET /save
Write-Host "4. TESTE: Salvar CSV (GET /save)" -ForegroundColor Cyan
$result4 = Testar-Endpoint -Metodo "GET" -Endpoint "/save" -Descricao "Salvar tasks em CSV no S3"
Write-Host ""

# Resumo
Write-Host "========================================" -ForegroundColor Green
Write-Host "  RESUMO DOS TESTES" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Sucessos: $sucessos" -ForegroundColor Green
Write-Host "Erros: $erros" -ForegroundColor $(if ($erros -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($erros -eq 0) {
    Write-Host "TODOS OS TESTES PASSARAM!" -ForegroundColor Green
} else {
    Write-Host "Alguns testes falharam. Verifique os erros acima." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possiveis causas:" -ForegroundColor Cyan
    Write-Host "  1. Tabela 'tasks' nao existe no banco" -ForegroundColor White
    Write-Host "  2. Lambdas nao atualizadas com codigo corrigido" -ForegroundColor White
    Write-Host "  3. Variaveis de ambiente incorretas nas Lambdas" -ForegroundColor White
    Write-Host "  4. Problemas de rede/VPC" -ForegroundColor White
}

Write-Host ""
Write-Host "=== FIM DOS TESTES ===" -ForegroundColor Green
