# Script para criar tabela automaticamente no RDS após terraform apply
# Execute este script após o RDS estar disponível
# 
# Uso manual:
#   cd projeto_nuvem/infra
#   .\init-database.ps1
#
# Ou via Terraform (null_resource executa automaticamente)

param(
    [string]$AWS_REGION = "sa-east-1"
)

Write-Host ""
Write-Host "=== Criando tabela 'tasks' no RDS automaticamente ===" -ForegroundColor Green
Write-Host ""

# Verificar se estamos no diretório correto e se o Terraform está inicializado
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

if (-not (Test-Path ".terraform") -and -not (Test-Path "terraform.tfstate") -and -not (Test-Path ".terraform.lock.hcl")) {
    Write-Host "⚠️ AVISO: Terraform não parece estar inicializado neste diretório" -ForegroundColor Yellow
    Write-Host "   Diretório atual: $(Get-Location)" -ForegroundColor Gray
    Write-Host "   Certifique-se de estar no diretório 'infra' e execute 'terraform init' primeiro." -ForegroundColor Yellow
    Write-Host ""
}

# Verificar se o Terraform está disponível
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERRO: Terraform não encontrado no PATH!" -ForegroundColor Red
    Write-Host "   Instale o Terraform ou adicione-o ao PATH." -ForegroundColor Yellow
    Pop-Location
    exit 1
}

# Obter informações via terraform output
Write-Host "Obtendo informações do RDS via terraform output..." -ForegroundColor Yellow

$RDS_ENDPOINT = terraform output -raw rds_endpoint 2>$null
if ([string]::IsNullOrEmpty($RDS_ENDPOINT)) {
    Write-Host "❌ ERRO: Não foi possível obter RDS endpoint." -ForegroundColor Red
    Write-Host "   Execute 'terraform apply' primeiro!" -ForegroundColor Yellow
    exit 1
}

$SECRET_ARN = terraform output -raw rds_secret_arn 2>$null
if ([string]::IsNullOrEmpty($SECRET_ARN)) {
    Write-Host "❌ ERRO: Não foi possível obter Secret ARN." -ForegroundColor Red
    Write-Host "   Execute 'terraform apply' primeiro!" -ForegroundColor Yellow
    exit 1
}

# Remover porta do endpoint (se houver)
$RDS_HOST = $RDS_ENDPOINT -replace ':\d+$', ''
$RDS_PORT = if ($RDS_ENDPOINT -match ':(\d+)$') { $matches[1] } else { "3306" }

Write-Host "✅ Informações obtidas:" -ForegroundColor Green
Write-Host "   RDS Host: $RDS_HOST" -ForegroundColor Cyan
Write-Host "   RDS Port: $RDS_PORT" -ForegroundColor Cyan
Write-Host "   Secret ARN: $SECRET_ARN" -ForegroundColor Cyan
Write-Host "   Region: $AWS_REGION" -ForegroundColor Cyan
Write-Host ""

# Obter credenciais do Secrets Manager
Write-Host "Obtendo credenciais do Secrets Manager..." -ForegroundColor Yellow
try {
    $secretValue = aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $AWS_REGION --query SecretString --output text 2>$null
    if ([string]::IsNullOrEmpty($secretValue)) {
        throw "Secret não encontrado"
    }
    
    $creds = $secretValue | ConvertFrom-Json
    Write-Host "✅ Credenciais obtidas" -ForegroundColor Green
    Write-Host "   Username: $($creds.username)" -ForegroundColor Gray
    Write-Host "   Database: $($creds.dbname)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ ERRO ao obter credenciais: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Criando Lambda temporária para executar SQL..." -ForegroundColor Yellow

# Verificar se já existe Lambda de init e deletar se existir
$LAMBDA_NAME = "nuvem-init-db"
aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Lambda já existe, deletando antes de criar nova..." -ForegroundColor Yellow
    aws lambda delete-function --function-name $LAMBDA_NAME --region $AWS_REGION 2>$null | Out-Null
    Start-Sleep -Seconds 2
}

# Criar ZIP da Lambda inline
$LAMBDA_CODE = @"
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const mysql = require('mysql2/promise');

// A região é detectada automaticamente pelo SDK quando executado dentro da Lambda
// Não precisamos definir manualmente - o SDK usa a região da Lambda automaticamente
const secretsManager = new SecretsManagerClient();

exports.handler = async (event) => {
  let connection = null;
  try {
    console.log('=== Iniciando criação da tabela ===');
    console.log('RDS_HOST:', process.env.RDS_HOST);
    console.log('RDS_PORT:', process.env.RDS_PORT);
    console.log('SECRET_ARN:', process.env.SECRET_ARN);
    
    // Obter credenciais
    console.log('Obtendo credenciais do Secrets Manager...');
    const command = new GetSecretValueCommand({ SecretId: process.env.SECRET_ARN });
    const secretResponse = await secretsManager.send(command);
    
    const creds = JSON.parse(secretResponse.SecretString);
    console.log('Credenciais obtidas. Username:', creds.username);
    console.log('Database:', creds.dbname);
    
    // Limpar host (remover porta se houver)
    const rdsHost = process.env.RDS_HOST.replace(/:\d+$/, '');
    const rdsPort = parseInt(process.env.RDS_PORT || '3306');
    
    console.log('Conectando ao RDS...');
    console.log('Host:', rdsHost);
    console.log('Port:', rdsPort);
    
    // Conectar ao RDS (sem database específico primeiro)
    connection = await mysql.createConnection({
      host: rdsHost,
      port: rdsPort,
      user: creds.username,
      password: creds.password,
      multipleStatements: false  // Desabilitar para evitar problemas
    });
    
    console.log('✅ Conectado ao RDS MySQL');
    
    // Criar database
    console.log('Criando database tasksdb...');
    await connection.query('CREATE DATABASE IF NOT EXISTS tasksdb');
    console.log('✅ Database tasksdb criado ou já existe');
    
    // Selecionar database
    await connection.query('USE tasksdb');
    console.log('✅ Database tasksdb selecionado');
    
    // Criar tabela
    console.log('Criando tabela tasks...');
    const createTableSQL = 'CREATE TABLE IF NOT EXISTS tasks (' +
      'id INT AUTO_INCREMENT PRIMARY KEY, ' +
      'title VARCHAR(255) NOT NULL, ' +
      'description TEXT, ' +
      'status VARCHAR(50) DEFAULT \"pending\", ' +
      'created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ' +
      'updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ' +
      'INDEX idx_status (status), ' +
      'INDEX idx_created_at (created_at) ' +
      ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
    
    await connection.query(createTableSQL);
    console.log('✅ Tabela tasks criada ou já existe');
    
    // Verificar se a tabela foi criada
    const [tables] = await connection.query('SHOW TABLES LIKE \"tasks\"');
    if (tables.length > 0) {
      console.log('✅ Confirmação: Tabela tasks existe no banco');
      
      // Verificar estrutura
      const [columns] = await connection.query('DESCRIBE tasks');
      console.log('Colunas da tabela:', JSON.stringify(columns, null, 2));
    } else {
      throw new Error('Tabela tasks não foi criada (verificação falhou)');
    }
    
    await connection.end();
    connection = null;
    
    console.log('=== Tabela criada com sucesso! ===');
    return { 
      statusCode: 200, 
      body: JSON.stringify({ 
        message: 'Tabela tasks criada com sucesso!',
        database: 'tasksdb',
        table: 'tasks'
      }) 
    };
  } catch (error) {
    console.error('❌ ERRO:', error);
    console.error('Stack:', error.stack);
    
    if (connection) {
      try {
        await connection.end();
      } catch (e) {
        console.error('Erro ao fechar conexão:', e);
      }
    }
    
    return { 
      statusCode: 500, 
      body: JSON.stringify({ 
        error: error.message,
        stack: error.stack,
        details: error.toString()
      }) 
    };
  }
};
"@

# Criar diretório temporário para Lambda
$TEMP_DIR = "$env:TEMP\nuvem-init-db-$(Get-Random)"
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

try {
    # Criar package.json
    $packageJson = @"
{
  "name": "init-db",
  "version": "1.0.0",
  "description": "Lambda para criar tabela no RDS",
  "main": "index.js",
  "dependencies": {
    "mysql2": "^3.9.1",
    "@aws-sdk/client-secrets-manager": "^3.0.0"
  }
}
"@
    $packageJson | Out-File -FilePath "$TEMP_DIR\package.json" -Encoding utf8
    
    # Criar index.js
    $LAMBDA_CODE | Out-File -FilePath "$TEMP_DIR\index.js" -Encoding utf8
    
    # Instalar dependências e criar ZIP
    Write-Host "Instalando dependências npm..." -ForegroundColor Yellow
    Push-Location $TEMP_DIR
    
    # Verificar se npm está disponível
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm não encontrado! Instale Node.js primeiro."
    }
    
    Write-Host "   Executando: npm install --production" -ForegroundColor Gray
    $npmOutput = npm install --production 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ ERRO ao instalar dependências npm:" -ForegroundColor Red
        Write-Host "$npmOutput" -ForegroundColor Red
        throw "Falha ao instalar dependências npm"
    }
    Write-Host "✅ Dependências instaladas" -ForegroundColor Green
    
    Write-Host "Criando ZIP do pacote Lambda..." -ForegroundColor Yellow
    Compress-Archive -Path * -DestinationPath "function.zip" -Force
    
    if (-not (Test-Path "function.zip")) {
        throw "Falha ao criar arquivo ZIP"
    }
    
    $zipSize = (Get-Item "function.zip").Length / 1MB
    Write-Host "✅ ZIP criado: function.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
    
    # Obter VPC ID, Subnet IDs e Security Group
    Write-Host "Configurando rede..." -ForegroundColor Yellow
    
    # ============================================================================
    # CONFIGURAÇÃO MANUAL - Valores obtidos do terraform apply
    # ============================================================================
    # Se o terraform output não funcionar, use estes valores diretamente
    # Para obter os valores corretos, execute: terraform output
    # ============================================================================
    
    # Valores do seu ambiente (obtidos do terraform apply)
    $VPC_ID = "vpc-0187c0d7d7df5ff73"
    $SUBNET_IDS = @("subnet-008d35b42294d27f6", "subnet-0c416190b62249552")
    $SECURITY_GROUP_ID = "sg-0f35b2b6f22f18c3a"
    
    Write-Host "✅ Configuração de rede (valores fixos):" -ForegroundColor Green
    Write-Host "   VPC: $VPC_ID" -ForegroundColor Cyan
    Write-Host "   Subnets: $($SUBNET_IDS -join ', ')" -ForegroundColor Cyan
    Write-Host "   Security Group: $SECURITY_GROUP_ID" -ForegroundColor Cyan
    Write-Host ""
    
    # ============================================================================
    # CÓDIGO ORIGINAL (COMENTADO) - Descomente se quiser tentar obter automaticamente
    # ============================================================================
    <#
    # Método 1: Tentar obter via terraform state show (mais confiável com backend remoto)
    Write-Host "Buscando VPC ID do Terraform state..." -ForegroundColor Yellow
    $vpcState = terraform state show aws_vpc.main 2>&1 | Out-String
    $VPC_ID = $null
    
    if ($vpcState -and $vpcState -notmatch "No state|Error|No such resource") {
        $vpcLine = $vpcState | Select-String '\sid\s+=' | Select-Object -First 1
        if ($vpcLine) {
            $VPC_ID = ($vpcLine.ToString() -split '=')[1].Trim().Trim('"')
            if ($VPC_ID -match "^vpc-") {
                Write-Host "✅ VPC ID obtido via state: $VPC_ID" -ForegroundColor Green
            } else {
                $VPC_ID = $null
            }
        }
    }
    
    # Método 2: Tentar obter via terraform output -json
    if ([string]::IsNullOrEmpty($VPC_ID)) {
        Write-Host "Tentando obter VPC ID via terraform output -json..." -ForegroundColor Yellow
        $allOutputs = terraform output -json 2>&1
        if ($allOutputs -and $allOutputs -notmatch "Warning|Error|No outputs") {
            try {
                $outputsObj = $allOutputs | ConvertFrom-Json
                if ($outputsObj.vpc_id -and $outputsObj.vpc_id.value) {
                    $VPC_ID = $outputsObj.vpc_id.value.ToString().Trim().Trim('"')
                    if ($VPC_ID -match "^vpc-") {
                        Write-Host "✅ VPC ID obtido via output JSON: $VPC_ID" -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "   Erro ao processar JSON: $_" -ForegroundColor Gray
            }
        }
    }
    
    # Método 3: Tentar obter via terraform output -raw
    if ([string]::IsNullOrEmpty($VPC_ID)) {
        Write-Host "Tentando obter VPC ID via terraform output -raw..." -ForegroundColor Yellow
        $VPC_ID_RAW = terraform output -raw vpc_id 2>&1
        if ($VPC_ID_RAW -and $VPC_ID_RAW -notmatch "Warning|Error|No outputs|No value") {
            $VPC_ID = $VPC_ID_RAW.ToString().Trim().Trim('"').Trim()
            if ($VPC_ID -match "^vpc-") {
                Write-Host "✅ VPC ID obtido via output raw: $VPC_ID" -ForegroundColor Green
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($VPC_ID) -or -not ($VPC_ID -match "^vpc-")) {
        Write-Host "❌ ERRO: Não foi possível obter VPC ID do Terraform!" -ForegroundColor Red
        Write-Host "   Use os valores fixos no início desta seção." -ForegroundColor Yellow
        throw "VPC ID não encontrado"
    }
    #>
    
    # Obter IAM Role da Lambda
    Write-Host "Obtendo IAM Role da Lambda..." -ForegroundColor Yellow
    
    # Valor fixo obtido do terraform apply
    $LAMBDA_ROLE = "arn:aws:iam::106343314372:role/nuvem-lambda-role"
    
    Write-Host "✅ Lambda Role: $LAMBDA_ROLE" -ForegroundColor Green
    Write-Host ""
    
    # Preparar variáveis de ambiente
    $subnet1 = $SUBNET_IDS[0]
    $subnet2 = $SUBNET_IDS[1]
    $zipFilePath = "$TEMP_DIR\function.zip"
    
    Write-Host "=== Criando função Lambda ===" -ForegroundColor Yellow
    Write-Host "   Nome: $LAMBDA_NAME" -ForegroundColor Gray
    Write-Host "   Runtime: nodejs20.x" -ForegroundColor Gray
    Write-Host "   Handler: index.handler" -ForegroundColor Gray
    Write-Host "   Timeout: 60 segundos" -ForegroundColor Gray
    Write-Host "   VPC: $VPC_ID" -ForegroundColor Gray
    Write-Host "   Subnets: $subnet1, $subnet2" -ForegroundColor Gray
    Write-Host "   Security Group: $SECURITY_GROUP_ID" -ForegroundColor Gray
    Write-Host "   RDS Host: $RDS_HOST" -ForegroundColor Gray
    Write-Host "   RDS Port: $RDS_PORT" -ForegroundColor Gray
    Write-Host ""
    
    # Usar formato direto sem arquivo (mais confiável no PowerShell/Windows)
    $env:AWS_PAGER = ""
    $createOutput = & aws lambda create-function `
        --function-name $LAMBDA_NAME `
        --runtime nodejs20.x `
        --role $LAMBDA_ROLE `
        --handler index.handler `
        --zip-file fileb://$zipFilePath `
        --timeout 60 `
        --environment "Variables={RDS_HOST=$RDS_HOST,RDS_PORT=$RDS_PORT,SECRET_ARN=$SECRET_ARN}" `
        --vpc-config "SubnetIds=$subnet1,$subnet2,SecurityGroupIds=$SECURITY_GROUP_ID" `
        --region $AWS_REGION 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        if ($createOutput -match "already exists" -or $createOutput -match "ResourceConflictException") {
            Write-Host "⚠️ Lambda já existe. Atualizando código e configuração..." -ForegroundColor Yellow
            
            # Atualizar código da Lambda existente
            Write-Host "   Atualizando código..." -ForegroundColor Gray
            $updateCodeOutput = aws lambda update-function-code `
                --function-name $LAMBDA_NAME `
                --zip-file "fileb://$zipFilePath" `
                --region $AWS_REGION 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️ Aviso ao atualizar código: $updateCodeOutput" -ForegroundColor Yellow
            }
            
            # Aguardar atualização do código
            Start-Sleep -Seconds 3
            
            # Atualizar configuração (incluindo VPC, timeout e environment)
            Write-Host "   Atualizando configuração (VPC, timeout, environment)..." -ForegroundColor Gray
            $updateConfigOutput = aws lambda update-function-configuration `
                --function-name $LAMBDA_NAME `
                --timeout 60 `
                --environment "Variables={RDS_HOST=$RDS_HOST,RDS_PORT=$RDS_PORT,SECRET_ARN=$SECRET_ARN}" `
                --vpc-config "SubnetIds=$subnet1,$subnet2,SecurityGroupIds=$SECURITY_GROUP_ID" `
                --region $AWS_REGION 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️ Aviso ao atualizar configuração: $updateConfigOutput" -ForegroundColor Yellow
            } else {
                Write-Host "✅ Lambda atualizada com sucesso" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ ERRO ao criar Lambda:" -ForegroundColor Red
            Write-Host "$createOutput" -ForegroundColor Red
            throw "Falha ao criar Lambda"
        }
    } else {
        Write-Host "✅ Lambda criada com sucesso" -ForegroundColor Green
    }
    
    # Aguardar Lambda ficar disponível (VPC pode demorar até 60 segundos)
    Write-Host "Aguardando Lambda ficar disponível (pode levar até 60 segundos para VPC)..." -ForegroundColor Yellow
    $maxWait = 12  # 12 tentativas de 5 segundos = 60 segundos
    $waitCount = 0
    $lambdaReady = $false
    
    while ($waitCount -lt $maxWait -and -not $lambdaReady) {
        Start-Sleep -Seconds 5
        $waitCount++
        Write-Host "   Tentativa $waitCount/$maxWait..." -ForegroundColor Gray
        
        $lambdaStatus = aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION --query 'Configuration.State' --output text 2>$null
        if ($lambdaStatus -eq "Active") {
            $lastUpdate = aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION --query 'Configuration.LastUpdateStatus' --output text 2>$null
            if ($lastUpdate -eq "Successful") {
                $lambdaReady = $true
                Write-Host "✅ Lambda está pronta!" -ForegroundColor Green
            }
        }
    }
    
    if (-not $lambdaReady) {
        Write-Host "⚠️ Lambda ainda não está pronta, mas vamos tentar invocar mesmo assim..." -ForegroundColor Yellow
    }
    
    # Invocar Lambda
    Write-Host ""
    Write-Host "Executando Lambda para criar tabela..." -ForegroundColor Yellow
    $responseFile = Join-Path $TEMP_DIR "response.json"
    
    # Aguardar um pouco mais antes de invocar
    Start-Sleep -Seconds 5
    
    $invokeOutput = aws lambda invoke `
        --function-name $LAMBDA_NAME `
        --region $AWS_REGION `
        --payload '{}' `
        --log-type Tail `
        $responseFile 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Lambda invocada com sucesso" -ForegroundColor Green
        
        # Ler resposta
        if (Test-Path $responseFile) {
            $responseContent = Get-Content $responseFile -Raw
            Write-Host ""
            Write-Host "Resposta bruta da Lambda:" -ForegroundColor Cyan
            Write-Host $responseContent -ForegroundColor Gray
            Write-Host ""
            
            try {
                $response = $responseContent | ConvertFrom-Json
                
                # Verificar se tem statusCode
                if ($response.PSObject.Properties.Name -contains "statusCode") {
                    if ($response.statusCode -eq 200) {
                        Write-Host "✅ Tabela criada com sucesso!" -ForegroundColor Green
                        if ($response.body) {
                            try {
                                $bodyObj = $response.body | ConvertFrom-Json
                                Write-Host "   $($bodyObj.message)" -ForegroundColor Gray
                            } catch {
                                Write-Host "   $($response.body)" -ForegroundColor Gray
                            }
                        }
                    } else {
                        Write-Host "❌ ERRO ao criar tabela! Status: $($response.statusCode)" -ForegroundColor Red
                        if ($response.body) {
                            try {
                                $bodyObj = $response.body | ConvertFrom-Json
                                Write-Host "   Erro: $($bodyObj.error)" -ForegroundColor Red
                            } catch {
                                Write-Host "   Resposta: $($response.body)" -ForegroundColor Red
                            }
                        }
                    }
                } else {
                    # Resposta pode estar em formato diferente
                    Write-Host "⚠️ Resposta em formato inesperado:" -ForegroundColor Yellow
                    $response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
                }
            } catch {
                Write-Host "❌ ERRO ao processar resposta da Lambda: $_" -ForegroundColor Red
                Write-Host "   Conteúdo bruto: $responseContent" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ Arquivo de resposta não foi criado!" -ForegroundColor Red
        }
        
        # Verificar logs da Lambda (MUITO IMPORTANTE)
        Write-Host ""
        Write-Host "=== LOGS DA LAMBDA (últimos 50 linhas) ===" -ForegroundColor Cyan
        Start-Sleep -Seconds 3  # Aguardar logs aparecerem
        $logs = aws logs tail "/aws/lambda/$LAMBDA_NAME" --since 5m --region $AWS_REGION 2>&1
        if ($logs) {
            $logs | Write-Host -ForegroundColor Yellow
        } else {
            Write-Host "   Nenhum log encontrado (pode levar alguns segundos para aparecer)" -ForegroundColor Gray
            Write-Host "   Verifique manualmente: aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $AWS_REGION" -ForegroundColor Gray
        }
        
        # Verificar status da Lambda
        Write-Host ""
        Write-Host "=== STATUS DA LAMBDA ===" -ForegroundColor Cyan
        aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION --query 'Configuration.{State:State,LastUpdateStatus:LastUpdateStatus,StateReason:StateReason,LastUpdateStatusReason:LastUpdateStatusReason}' --output table 2>&1 | Write-Host -ForegroundColor Gray
        
    } else {
        Write-Host "❌ ERRO ao invocar Lambda" -ForegroundColor Red
        Write-Host "Saída do comando:" -ForegroundColor Yellow
        Write-Host "$invokeOutput" -ForegroundColor Red
        
        # Verificar se Lambda existe e status
        Write-Host ""
        Write-Host "Verificando status da Lambda..." -ForegroundColor Yellow
        $lambdaInfo = aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Lambda existe. Status:" -ForegroundColor Cyan
            aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION --query 'Configuration.{State:State,LastUpdateStatus:LastUpdateStatus,StateReason:StateReason,LastUpdateStatusReason:LastUpdateStatusReason}' --output table 2>&1 | Write-Host -ForegroundColor Gray
        } else {
            Write-Host "❌ Lambda não encontrada ou erro ao verificar:" -ForegroundColor Red
            Write-Host "$lambdaInfo" -ForegroundColor Red
        }
        
        # Mostrar logs mesmo em caso de erro
        Write-Host ""
        Write-Host "=== TENTANDO OBTER LOGS ===" -ForegroundColor Cyan
        $logs = aws logs tail "/aws/lambda/$LAMBDA_NAME" --since 10m --region $AWS_REGION 2>&1
        if ($logs) {
            $logs | Write-Host -ForegroundColor Yellow
        }
    }
    
    # Deletar Lambda
    Write-Host ""
    Write-Host "Limpando Lambda temporária..." -ForegroundColor Yellow
    aws lambda delete-function --function-name $LAMBDA_NAME --region $AWS_REGION 2>$null | Out-Null
    Write-Host "✅ Limpeza concluída" -ForegroundColor Green
    
} finally {
    Pop-Location
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Concluído! ===" -ForegroundColor Green

