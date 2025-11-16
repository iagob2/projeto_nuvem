# 📘 Guia Completo de Uso da Infraestrutura

Este documento fornece instruções detalhadas sobre como usar todos os recursos criados pela infraestrutura Terraform.

---

## 📋 Índice

1. [Obter Informações da Infraestrutura](#1-obter-informações-da-infraestrutura)
2. [Testar API Gateway e Lambda](#2-testar-api-gateway-e-lambda)
3. [Conectar ao RDS MySQL](#3-conectar-ao-rds-mysql)
4. [Acessar o EC2 Frontend](#4-acessar-o-ec2-frontend)
5. [Usar o Bucket S3 CSV](#5-usar-o-bucket-s3-csv)
6. [Verificar Logs e Monitoramento](#6-verificar-logs-e-monitoramento)

---

## 1. Obter Informações da Infraestrutura

### 1.1 Obter Todos os Outputs

Execute o comando no diretório `infra`:

```powershell
terraform output
```

Isso mostrará todas as informações importantes da sua infraestrutura:

```powershell
# Exemplo de saída:
api_gateway_invoke_url = "https://kq5q2cp8si.execute-api.sa-east-1.amazonaws.com/dev"
rds_endpoint = "tasks-db.c50umqmk8mal.sa-east-1.rds.amazonaws.com:3306"
ec2_frontend_public_ip = "177.71.247.25"
s3_bucket_name = "meu-bucket-tasks-csv-unico"
```

### 1.2 Obter Outputs Específicos

Para obter um output específico:

```powershell
# API Gateway URL
terraform output api_gateway_invoke_url

# RDS Endpoint
terraform output rds_endpoint

# EC2 IP Público
terraform output ec2_frontend_public_ip

# S3 Bucket CSV
terraform output s3_bucket_name

# RDS Secret ARN (para Lambda/ECS)
terraform output rds_secret_arn
```

### 1.3 Obter Outputs em Formato JSON

```powershell
terraform output -json
```

---

## 2. Testar API Gateway e Lambda

### 2.1 Obter a URL do API Gateway

```powershell
$API_URL = terraform output -raw api_gateway_invoke_url
Write-Host "API URL: $API_URL"
```

### 2.2 Testar com PowerShell (Invoke-RestMethod)

#### Teste GET (Listar Tasks)

```powershell
$API_URL = terraform output -raw api_gateway_invoke_url

# Fazer requisição GET
$response = Invoke-RestMethod -Uri "$API_URL/tasks" -Method GET -ContentType "application/json"

# Mostrar resposta
$response | ConvertTo-Json -Depth 10
```

#### Teste POST (Criar Task)

```powershell
$API_URL = terraform output -raw api_gateway_invoke_url

# Dados para criar uma task
$taskData = @{
    title = "Minha Primeira Task"
    description = "Descrição da task"
    status = "pending"
} | ConvertTo-Json

# Fazer requisição POST
$response = Invoke-RestMethod -Uri "$API_URL/tasks" -Method POST -Body $taskData -ContentType "application/json"

# Mostrar resposta
$response | ConvertTo-Json -Depth 10
```

#### Teste PUT (Atualizar Task)

```powershell
$API_URL = terraform output -raw api_gateway_invoke_url
$TASK_ID = "1"  # ID da task a atualizar

# Dados para atualizar
$taskData = @{
    title = "Task Atualizada"
    status = "completed"
} | ConvertTo-Json

# Fazer requisição PUT
$response = Invoke-RestMethod -Uri "$API_URL/tasks/$TASK_ID" -Method PUT -Body $taskData -ContentType "application/json"

# Mostrar resposta
$response | ConvertTo-Json -Depth 10
```

#### Teste DELETE (Deletar Task)

```powershell
$API_URL = terraform output -raw api_gateway_invoke_url
$TASK_ID = "1"  # ID da task a deletar

# Fazer requisição DELETE
$response = Invoke-RestMethod -Uri "$API_URL/tasks/$TASK_ID" -Method DELETE -ContentType "application/json"

# Mostrar resposta
$response | ConvertTo-Json -Depth 10
```

### 2.3 Testar com cURL (se disponível)

```bash
# GET
curl -X GET "$API_URL/tasks"

# POST
curl -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title":"Nova Task","description":"Descrição","status":"pending"}'

# PUT
curl -X PUT "$API_URL/tasks/1" \
  -H "Content-Type: application/json" \
  -d '{"title":"Task Atualizada","status":"completed"}'

# DELETE
curl -X DELETE "$API_URL/tasks/1"
```

### 2.4 Testar com Postman ou Insomnia

1. **Importar URL do API Gateway:**
   - Método: GET/POST/PUT/DELETE
   - URL: `https://kq5q2cp8si.execute-api.sa-east-1.amazonaws.com/dev/{proxy+}`
   - Headers: `Content-Type: application/json`
   - Body (para POST/PUT): JSON com os dados da task

2. **Exemplo de Body JSON:**
   ```json
   {
     "title": "Minha Task",
     "description": "Descrição da task",
     "status": "pending"
   }
   ```

### 2.5 Verificar Logs da Lambda

```powershell
# Ver logs da Lambda via AWS CLI (se instalado)
aws logs tail /aws/lambda/CriarTask --follow --region sa-east-1

# Ou via Console AWS:
# 1. Acesse: https://console.aws.amazon.com/cloudwatch/
# 2. Vá para "Log groups"
# 3. Procure por: /aws/lambda/CriarTask
```

### 2.6 Troubleshooting da API Gateway

**Se receber erro 500:**
- Verifique os logs da Lambda no CloudWatch
- Verifique se a Lambda está na VPC correta
- Verifique os security groups

**Se receber erro 403:**
- Verifique a permissão Lambda Permission
- Verifique se o API Gateway tem permissão para invocar a Lambda

**Se receber erro 502:**
- Verifique se a Lambda está em execução
- Verifique o timeout da Lambda (configurado para 30 segundos)

---

## 3. Conectar ao RDS MySQL

### 3.1 Obter Informações do RDS

```powershell
# Endpoint completo (host:port)
terraform output rds_endpoint

# Apenas host
terraform output rds_address

# Porta
terraform output rds_port

# Secret ARN (contém credenciais)
terraform output rds_secret_arn
```

### 3.2 Obter Credenciais do Secrets Manager

#### Via AWS CLI

```powershell
# Obter ARN do secret
$SECRET_ARN = terraform output -raw rds_secret_arn

# Obter credenciais
aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region sa-east-1 | ConvertFrom-Json | Select-Object -ExpandProperty SecretString | ConvertFrom-Json
```

#### Via Console AWS

1. Acesse: https://console.aws.amazon.com/secretsmanager/
2. Procure pelo secret: `nuvem-rds-credentials`
3. Clique em "Retrieve secret value"
4. Veja as credenciais:
   ```json
   {
     "username": "admin",
     "password": "sua_senha",
     "engine": "mysql",
     "dbname": "tasksdb"
   }
   ```

### 3.3 Conectar via MySQL Client

#### Instalar MySQL Client (se necessário)

**Windows:**
```powershell
# Usando Chocolatey
choco install mysql

# Ou baixar de: https://dev.mysql.com/downloads/mysql/
```

#### Conectar ao RDS

```powershell
# Substitua pelos valores reais
$RDS_HOST = terraform output -raw rds_address
$RDS_PORT = terraform output -raw rds_port
$DB_USER = "admin"  # Do Secrets Manager
$DB_PASS = "sua_senha"  # Do Secrets Manager
$DB_NAME = "tasksdb"

# Conectar via MySQL CLI
mysql -h $RDS_HOST -P $RDS_PORT -u $DB_USER -p$DB_PASS $DB_NAME
```

**Exemplo de comando:**
```bash
mysql -h tasks-db.c50umqmk8mal.sa-east-1.rds.amazonaws.com -P 3306 -u admin -psua_senha tasksdb
```

### 3.4 Conectar via MySQL Workbench ou DBeaver

1. **Configurações de Conexão:**
   - **Host:** `tasks-db.c50umqmk8mal.sa-east-1.rds.amazonaws.com`
   - **Port:** `3306`
   - **Username:** Obtenha do Secrets Manager
   - **Password:** Obtenha do Secrets Manager
   - **Database:** `tasksdb` (ou o nome configurado)

2. **Testar Conexão:**
   - Clique em "Test Connection"
   - Se falhar, verifique os security groups do RDS

### 3.5 Conectar de uma EC2 dentro da VPC

Se você estiver em uma EC2 dentro da mesma VPC:

```bash
# A conexão será mais rápida (sem sair da VPC)
mysql -h tasks-db.c50umqmk8mal.sa-east-1.rds.amazonaws.com -u admin -p tasksdb
```

**Vantagens:**
- Mais rápido (tráfego interno)
- Não precisa configurar security groups para acesso externo

### 3.6 Conectar via Lambda/ECS

As aplicações Lambda e ECS já têm as credenciais configuradas via variáveis de ambiente:

```javascript
// Exemplo em Lambda
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();

// Obter credenciais
const secretResponse = await secretsManager.getSecretValue({
  SecretId: process.env.DB_SECRET_ARN
}).promise();

const credentials = JSON.parse(secretResponse.SecretString);

// Conectar ao RDS
const mysql = require('mysql2/promise');
const connection = await mysql.createConnection({
  host: process.env.RDS_ENDPOINT,
  port: process.env.RDS_PORT,
  user: credentials.username,
  password: credentials.password,
  database: process.env.DB_NAME
});
```

### 3.7 Troubleshooting da Conexão RDS

**Erro: "Can't connect to MySQL server":**
- Verifique os security groups do RDS
- Verifique se você está tentando conectar da rede correta
- RDS está em subnets privadas, só acessível de dentro da VPC

**Erro: "Access denied":**
- Verifique as credenciais no Secrets Manager
- Verifique se o usuário tem permissões

**Erro de Timeout:**
- Verifique se o RDS está em "available" status
- Verifique os route tables e NAT Gateway

---

## 4. Acessar o EC2 Frontend

### 4.1 Obter Informações da EC2

```powershell
# IP Público
terraform output ec2_frontend_public_ip

# Instance ID
terraform output ec2_frontend_instance_id
```

### 4.2 Acessar via SSH

#### Gerar/Copiar Chave SSH (se necessário)

Se você não tem uma chave SSH configurada:

1. **Gerar nova chave:**
   ```powershell
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/ec2-key
   ```

2. **Obter chave pública:**
   ```powershell
   Get-Content ~/.ssh/ec2-key.pub
   ```

3. **Adicionar à EC2:**
   - Via Console AWS → EC2 → Instances → Actions → Security → Modify instance attributes
   - Ou usar User Data script na criação

#### Conectar via SSH

```powershell
# Substitua pelos valores reais
$EC2_IP = terraform output -raw ec2_frontend_public_ip
$SSH_KEY = "~/.ssh/ec2-key"
$USER = "ec2-user"  # Para Amazon Linux, pode ser "ubuntu" para Ubuntu

# Conectar
ssh -i $SSH_KEY $USER@$EC2_IP
```

**Exemplo:**
```bash
ssh -i ~/.ssh/ec2-key ec2-user@177.71.247.25
```

### 4.3 Acessar via Browser (HTTP/HTTPS)

```powershell
# Obter IP
$EC2_IP = terraform output -raw ec2_frontend_public_ip

# Abrir no browser
Start-Process "http://$EC2_IP"
Start-Process "https://$EC2_IP"
```

**Exemplo:**
- HTTP: http://177.71.247.25
- HTTPS: https://177.71.247.25

### 4.4 Acessar via Session Manager (se configurado)

Se o Session Manager estiver configurado na EC2:

```powershell
# Instalar Session Manager Plugin (se necessário)
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Conectar
$INSTANCE_ID = terraform output -raw ec2_frontend_instance_id
aws ssm start-session --target $INSTANCE_ID --region sa-east-1
```

### 4.5 Verificar Status da EC2

```powershell
# Via AWS CLI
$INSTANCE_ID = terraform output -raw ec2_frontend_instance_id
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --region sa-east-1

# Via Console AWS
# https://console.aws.amazon.com/ec2/
```

### 4.6 Troubleshooting do EC2

**Erro de Conexão SSH:**
- Verifique o security group (deve permitir porta 22 do seu IP)
- Verifique se a instância está "running"
- Verifique se tem chave SSH configurada

**Erro de Conexão HTTP:**
- Verifique o security group (deve permitir portas 80/443)
- Verifique se o servidor web está rodando na EC2
- Verifique os logs da aplicação

**Timeout:**
- Verifique se a instância tem IP público
- Verifique os route tables

---

## 5. Usar o Bucket S3 CSV

### 5.1 Obter Informações do Bucket

```powershell
# Nome do bucket
terraform output s3_bucket_name

# ARN do bucket
terraform output s3_csv_bucket_arn

# ID do bucket
terraform output s3_csv_bucket_id
```

### 5.2 Upload de Arquivo via AWS CLI

#### Instalar AWS CLI (se necessário)

```powershell
# Windows
# Baixar de: https://aws.amazon.com/cli/
```

#### Configurar Credenciais

```powershell
# Configurar credenciais (se ainda não fez)
aws configure

# Ou usar variáveis de ambiente
$env:AWS_ACCESS_KEY_ID = "sua_access_key"
$env:AWS_SECRET_ACCESS_KEY = "sua_secret_key"
$env:AWS_DEFAULT_REGION = "sa-east-1"
```

#### Upload de Arquivo

```powershell
# Obter nome do bucket
$BUCKET_NAME = terraform output -raw s3_bucket_name

# Upload de um arquivo
aws s3 cp "C:\caminho\para\arquivo.csv" "s3://$BUCKET_NAME/tasks/arquivo.csv" --region sa-east-1

# Upload de múltiplos arquivos
aws s3 sync "C:\pasta\com\csvs" "s3://$BUCKET_NAME/tasks/" --region sa-east-1
```

**Exemplo:**
```bash
aws s3 cp "C:\data\tasks.csv" "s3://meu-bucket-tasks-csv-unico/tasks/tasks.csv" --region sa-east-1
```

### 5.3 Download de Arquivo via AWS CLI

```powershell
$BUCKET_NAME = terraform output -raw s3_bucket_name

# Download de um arquivo
aws s3 cp "s3://$BUCKET_NAME/tasks/arquivo.csv" "C:\downloads\arquivo.csv" --region sa-east-1

# Download de tudo
aws s3 sync "s3://$BUCKET_NAME/tasks/" "C:\downloads\" --region sa-east-1
```

### 5.4 Listar Arquivos no Bucket

```powershell
$BUCKET_NAME = terraform output -raw s3_bucket_name

# Listar todos os arquivos
aws s3 ls "s3://$BUCKET_NAME/" --recursive --region sa-east-1

# Listar arquivos em uma pasta específica
aws s3 ls "s3://$BUCKET_NAME/tasks/" --region sa-east-1
```

### 5.5 Usar via Console AWS

1. **Acesse o S3 Console:**
   https://console.aws.amazon.com/s3/

2. **Encontrar seu bucket:**
   - Procure por: `meu-bucket-tasks-csv-unico`

3. **Upload de arquivo:**
   - Clique no bucket
   - Clique em "Upload"
   - Arraste arquivos ou clique em "Add files"
   - Clique em "Upload"

4. **Download de arquivo:**
   - Navegue até o arquivo
   - Clique no arquivo
   - Clique em "Download"

5. **Criar pasta:**
   - Clique em "Create folder"
   - Digite o nome (ex: "tasks")
   - Clique em "Create folder"

### 5.6 Usar via SDK (JavaScript/Node.js)

```javascript
const AWS = require('aws-sdk');

// Configurar S3
const s3 = new AWS.S3({
  region: 'sa-east-1'
});

const BUCKET_NAME = 'meu-bucket-tasks-csv-unico';

// Upload de arquivo
async function uploadFile(filePath, key) {
  const fs = require('fs');
  const fileContent = fs.readFileSync(filePath);
  
  const params = {
    Bucket: BUCKET_NAME,
    Key: key,  // Ex: 'tasks/tasks.csv'
    Body: fileContent,
    ContentType: 'text/csv'
  };
  
  const result = await s3.upload(params).promise();
  console.log('Upload realizado:', result.Location);
  return result;
}

// Download de arquivo
async function downloadFile(key, localPath) {
  const params = {
    Bucket: BUCKET_NAME,
    Key: key
  };
  
  const data = await s3.getObject(params).promise();
  const fs = require('fs');
  fs.writeFileSync(localPath, data.Body);
  console.log('Download realizado:', localPath);
}

// Listar arquivos
async function listFiles(prefix = '') {
  const params = {
    Bucket: BUCKET_NAME,
    Prefix: prefix  // Ex: 'tasks/'
  };
  
  const data = await s3.listObjectsV2(params).promise();
  return data.Contents.map(item => item.Key);
}

// Exemplos de uso
// uploadFile('./tasks.csv', 'tasks/tasks.csv');
// downloadFile('tasks/tasks.csv', './downloads/tasks.csv');
// listFiles('tasks/').then(console.log);
```

### 5.7 Usar via PowerShell (SDK .NET)

```powershell
# Instalar AWS SDK (se necessário)
Install-Package AWSSDK.S3 -Scope CurrentUser

# Usar SDK
using namespace Amazon.S3
using namespace Amazon.S3.Model

$s3Client = New-Object Amazon.S3.AmazonS3Client([Amazon.RegionEndpoint]::SAEast1)
$bucketName = terraform output -raw s3_bucket_name

# Upload
$filePath = "C:\data\tasks.csv"
$key = "tasks/tasks.csv"
$content = [System.IO.File]::ReadAllBytes($filePath)

$request = New-Object PutObjectRequest
$request.BucketName = $bucketName
$request.Key = $key
$request.InputStream = New-Object System.IO.MemoryStream(,$content)

$response = $s3Client.PutObject($request)
Write-Host "Upload realizado: $($response.ETag)"

# Download
$request = New-Object GetObjectRequest
$request.BucketName = $bucketName
$request.Key = $key

$response = $s3Client.GetObject($request)
$response.ResponseStream.CopyTo([System.IO.File]::Create("C:\downloads\tasks.csv"))

# Listar
$request = New-Object ListObjectsV2Request
$request.BucketName = $bucketName
$request.Prefix = "tasks/"

$response = $s3Client.ListObjectsV2($request)
$response.S3Objects | ForEach-Object { Write-Host $_.Key }
```

### 5.8 Gerar URL Pré-assinada (Temporary URL)

```powershell
# Via AWS CLI (válida por 1 hora)
$BUCKET_NAME = terraform output -raw s3_bucket_name
aws s3 presign "s3://$BUCKET_NAME/tasks/arquivo.csv" --expires-in 3600 --region sa-east-1
```

**Via SDK:**
```javascript
const params = {
  Bucket: BUCKET_NAME,
  Key: 'tasks/tasks.csv',
  Expires: 3600  // 1 hora
};

const url = s3.getSignedUrl('getObject', params);
console.log('URL pré-assinada:', url);
```

### 5.9 Troubleshooting do S3

**Erro de Acesso Negado:**
- Verifique as credenciais AWS
- Verifique as IAM policies da sua conta
- Verifique se o bucket está na região correta

**Erro de Upload:**
- Verifique o tamanho do arquivo (limite padrão: 5GB)
- Verifique se tem permissão de escrita
- Verifique a conectividade de rede

**Bucket não encontrado:**
- Verifique o nome do bucket (é case-sensitive)
- Verifique a região (sa-east-1)

---

## 6. Verificar Logs e Monitoramento

### 6.1 Logs da Lambda

#### Via Console AWS

1. Acesse: https://console.aws.amazon.com/cloudwatch/
2. Vá para "Log groups"
3. Procure por: `/aws/lambda/CriarTask`
4. Clique para ver os logs

#### Via AWS CLI

```powershell
# Ver últimas 100 linhas
aws logs tail /aws/lambda/CriarTask --follow --region sa-east-1

# Ver logs de um período específico
aws logs filter-log-events \
  --log-group-name /aws/lambda/CriarTask \
  --start-time $(Get-Date (Get-Date).AddHours(-1) -UFormat %s)000 \
  --region sa-east-1
```

### 6.2 Logs do API Gateway

#### Via Console AWS

1. Acesse: https://console.aws.amazon.com/apigateway/
2. Selecione sua API: `nuvem-tasks-api`
3. Vá para "Logs / Execution Logs"
4. Veja os logs de execução

#### CloudWatch Log Group

```powershell
# Ver logs do API Gateway
aws logs tail /aws/apigateway/nuvem-tasks-api --follow --region sa-east-1
```

### 6.3 Métricas do RDS

1. Acesse: https://console.aws.amazon.com/rds/
2. Selecione sua instância: `tasks-db`
3. Vá para a aba "Monitoring"
4. Veja métricas como:
   - CPU Utilization
   - Database Connections
   - Freeable Memory
   - Read/Write IOPS

### 6.4 Métricas do EC2

1. Acesse: https://console.aws.amazon.com/ec2/
2. Selecione sua instância
3. Vá para a aba "Monitoring"
4. Veja métricas como:
   - CPU Utilization
   - Network In/Out
   - Status Check

### 6.5 CloudWatch Dashboards

Crie um dashboard personalizado:

1. Acesse: https://console.aws.amazon.com/cloudwatch/
2. Vá para "Dashboards"
3. Clique em "Create dashboard"
4. Adicione widgets para:
   - Lambda invocations
   - API Gateway requests
   - RDS connections
   - EC2 CPU

---

## 🔒 Segurança e Boas Práticas

### Boas Práticas

1. **Credenciais:**
   - ❌ NUNCA hardcode credenciais no código
   - ✅ Use AWS Secrets Manager
   - ✅ Use IAM roles para Lambda/ECS

2. **Acesso ao RDS:**
   - ❌ NÃO exponha RDS para internet
   - ✅ Mantenha RDS em subnets privadas
   - ✅ Use security groups restritivos

3. **S3 Buckets:**
   - ✅ Mantenha Block Public Access habilitado
   - ✅ Use IAM policies ao invés de ACLs
   - ✅ Habilite versionamento

4. **API Gateway:**
   - ✅ Considere adicionar autenticação (API Keys, Cognito)
   - ✅ Configure rate limiting
   - ✅ Use HTTPS apenas

---

## 🆘 Troubleshooting Geral

### Problema: Infraestrutura não está funcionando

1. **Verificar status dos recursos:**
   ```powershell
   terraform output
   ```

2. **Verificar logs:**
   - CloudWatch Logs
   - API Gateway Execution Logs
   - Lambda Logs

3. **Verificar security groups:**
   - Verifique se as regras permitem tráfego necessário
   - Verifique se os recursos estão na VPC correta

4. **Verificar conectividade:**
   - Teste ping/telnet para endpoints
   - Verifique DNS resolution

### Obter Ajuda

- **Documentação AWS:** https://docs.aws.amazon.com/
- **Terraform Docs:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **AWS Support:** https://console.aws.amazon.com/support/

---

## 📝 Notas Importantes

- **Região:** Todos os recursos estão em `sa-east-1` (São Paulo)
- **Ambiente:** Configurado como `dev` (pode ser alterado via variáveis)
- **Backup:** RDS tem backup automático configurado
- **Custos:** Monitore os custos via AWS Cost Explorer

---

**Última atualização:** 2025-11-15

