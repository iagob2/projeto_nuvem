# 🚀 Guia Completo de Deploy - Projeto Nuvem

**Objetivo:** Guia completo e detalhado para fazer deploy completo do projeto na AWS, incluindo criação de backend Terraform, infraestrutura, containerização e deploy de aplicações.

---

## 📋 Índice

1. [Pré-requisitos Completos](#pré-requisitos-completos)
2. [Criar Backend S3 e DynamoDB](#criar-backend-s3-e-dynamodb)
3. [Configurar Credenciais AWS](#configurar-credenciais-aws)
4. [Preparar Arquivos de Configuração](#preparar-arquivos-de-configuração)
5. [Deploy da Infraestrutura](#deploy-da-infraestrutura)
6. [Containerizar e Enviar Backend](#containerizar-e-enviar-backend)
7. [Containerizar e Enviar Frontend](#containerizar-e-enviar-frontend)
8. [Criar Tabela no Banco de Dados](#criar-tabela-no-banco-de-dados)
9. [Testar a Aplicação](#testar-a-aplicação)
10. [Scripts Disponíveis](#scripts-disponíveis)
11. [Troubleshooting](#troubleshooting)

---

## 📋 Pré-requisitos Completos

Antes de começar, certifique-se de ter instalado e configurado:

### ✅ Software Necessário

1. **Docker Desktop** (Windows)
   - Download: https://www.docker.com/products/docker-desktop
   - Verificar instalação:
   ```powershell
   docker --version
   docker ps
   ```

2. **AWS CLI**
   - Download: https://aws.amazon.com/cli/
   - Verificar instalação:
   ```powershell
   aws --version
   ```

3. **Terraform** (>= 1.0)
   - Download: https://www.terraform.io/downloads
   - Verificar instalação:
   ```powershell
   terraform version
   ```

4. **Node.js e npm** (para scripts de Lambda)
   - Download: https://nodejs.org/
   - Verificar instalação:
   ```powershell
   node --version
   npm --version
   ```

5. **PowerShell** (já vem com Windows)
   - Verificar versão:
   ```powershell
   $PSVersionTable.PSVersion
   ```

### ✅ Conta e Permissões AWS

- Conta AWS ativa
- Permissões para criar:
  - S3 Buckets
  - DynamoDB Tables
  - VPC, Subnets, Security Groups
  - RDS MySQL
  - ECR Repositories
  - ECS Clusters e Services
  - Lambda Functions
  - API Gateway
  - IAM Roles e Policies
  - Secrets Manager

### ✅ Estrutura do Projeto

Certifique-se de que a estrutura do projeto está assim:

```
projeto_nuvem/
├── infra/
│   ├── backend.tf
│   ├── terraform.tfvars
│   ├── setup-backend.tf
│   └── ...
├── back-end/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
├── front-end/
│   ├── Dockerfile
│   ├── public/
│   └── ...
├── lambda/
│   └── criar_task/
│       └── ...
└── scripts/
    ├── deploy-completo.ps1
    ├── testar-api-windows.ps1
    └── ...
```

### ⚠️ IMPORTANTE: Sintaxe PowerShell vs Linux/Mac

**No Windows PowerShell:**
- Use `` ` `` (crase invertida) para continuar linhas
- Variáveis: `$VAR`
- **NÃO** use `\` (barra invertida) para continuar linhas - isso é sintaxe de Linux/Mac

**Exemplo correto no PowerShell:**
```powershell
aws ecs describe-services `
  --cluster $CLUSTER_ID `
  --services back-end-service `
  --region $AWS_REGION
```

**Exemplo correto no Linux/Mac:**
```bash
aws ecs describe-services \
  --cluster $CLUSTER_ID \
  --services back-end-service \
  --region $AWS_REGION
```

---

## 🔧 Criar Backend S3 e DynamoDB

**⚠️ CRÍTICO:** O backend do Terraform (S3 + DynamoDB) DEVE ser criado ANTES de executar `terraform init` no projeto principal!

O Terraform precisa de um local remoto para armazenar o estado (state file) e um mecanismo de locking para evitar conflitos. Isso é feito através de:
- **S3 Bucket**: Armazena o arquivo `terraform.tfstate`
- **DynamoDB Table**: Fornece locking (evita execuções simultâneas)

### 📝 Informações do Backend

De acordo com `infra/backend.tf`, você precisa criar:
- **Bucket S3**: `meu-terraform-state-bucket-uniqueno21` (ou similar - o nome pode ter sufixos)
- **Tabela DynamoDB**: `terraform-locks`
- **Região**: `us-east-2` (conforme configurado no backend.tf)

**⚠️ IMPORTANTE:** 
- O bucket está configurado para `us-east-2`, mas a infraestrutura principal será criada em `sa-east-1`. Isso é normal - o backend pode estar em uma região diferente.
- **O nome do bucket S3 deve ser EXATAMENTE o mesmo que está configurado no `backend.tf`!** Se você criou o bucket com um nome diferente (ex: com sufixo "21"), atualize o `backend.tf` para usar o nome correto.
- Para verificar o nome exato do bucket criado, use: `aws s3 ls --region us-east-2`

---

### 🚀 Opção 1: Criar Backend com Terraform (Recomendado)

Esta é a forma mais automatizada e recomendada.

#### Passo 1: Criar diretório temporário

```powershell
# Criar diretório fora do projeto principal
cd D:\
mkdir terraform-backend-setup
cd terraform-backend-setup
```

#### Passo 2: Copiar arquivo de setup

```powershell
# Voltar para o projeto e copiar o arquivo
cd "D:\iagob2\fatec  - semestre 6\Computacao em Nuvem II\projeto_testes\projeto_nuvem\infra"
copy setup-backend.tf D:\terraform-backend-setup\
```

#### Passo 3: Criar arquivo providers.tf

No diretório `D:\terraform-backend-setup\`, crie um arquivo `providers.tf`:

```powershell
cd D:\terraform-backend-setup
@"
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"  # Região do backend (conforme backend.tf)
}
"@ | Out-File -FilePath "providers.tf" -Encoding utf8
```

#### Passo 4: Criar arquivo para o S3

O `setup-backend.tf` atual só cria o DynamoDB. Vamos criar também o S3. Crie `s3-backend.tf`:

```powershell
@"
# Bucket S3 para armazenar o state do Terraform
# ⚠️ IMPORTANTE: Use o nome EXATO do bucket que você criou (pode ter sufixos como "21")
resource "aws_s3_bucket" "terraform_state" {
  bucket = "meu-terraform-state-bucket-uniqueno21"  # Ajuste para o nome real do seu bucket
  
  # Prevenir exclusão acidental
  lifecycle {
    prevent_destroy = false
  }
  
  tags = {
    Name      = "Terraform State Bucket"
    Purpose   = "Terraform Backend"
    ManagedBy = "Terraform"
  }
}

# Habilitar versionamento
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Habilitar encriptação
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acesso público
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output
output "s3_bucket_name" {
  description = "Nome do bucket S3 para state"
  value       = aws_s3_bucket.terraform_state.id
}
"@ | Out-File -FilePath "s3-backend.tf" -Encoding utf8
```

#### Passo 5: Inicializar Terraform (sem backend)

```powershell
terraform init
```

**✅ Saída esperada:**
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

#### Passo 6: Verificar o que será criado

```powershell
terraform plan
```

**✅ Deve mostrar:**
- 1 recurso S3 (bucket)
- 1 recurso DynamoDB (tabela)
- Recursos de versionamento e encriptação

#### Passo 7: Criar os recursos

```powershell
terraform apply
```

Quando perguntar se deseja continuar, digite: `yes`

**⏱️ Tempo estimado:** 1-2 minutos

**✅ Saída esperada:**
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

Outputs:

dynamodb_table_name = "terraform-locks"
s3_bucket_name = "meu-terraform-state-bucket-uniqueno"
```

#### Passo 8: Verificar criação

```powershell
# Verificar bucket S3
aws s3 ls | Select-String "meu-terraform-state-bucket-uniqueno"

# Verificar tabela DynamoDB
aws dynamodb list-tables --region us-east-2 | Select-String "terraform-locks"
```

**✅ Se ambos aparecerem, o backend foi criado com sucesso!**

---

### 🚀 Opção 2: Criar Backend Manualmente via AWS Console

Se preferir criar manualmente ou se a Opção 1 não funcionar.

#### Criar Bucket S3

1. Acesse: https://console.aws.amazon.com/s3/
2. **⚠️ IMPORTANTE:** Certifique-se de estar na região **US East (Ohio) - us-east-2**
3. Clique em **"Create bucket"**
4. Configure:
   - **Bucket name**: `meu-terraform-state-bucket-uniqueno21` (ou o nome que você escolher - deve ser único globalmente)
   - **Region**: `US East (Ohio) - us-east-2`
   - **Block Public Access**: ✅ Habilitar tudo (bloquear acesso público)
   - **Bucket Versioning**: ✅ Habilitar
   - **Default encryption**: ✅ Habilitar (AES256)
5. Clique em **"Create bucket"**

#### Criar Tabela DynamoDB

1. Acesse: https://console.aws.amazon.com/dynamodb/
2. **⚠️ IMPORTANTE:** Certifique-se de estar na região **US East (Ohio) - us-east-2**
3. Clique em **"Create table"**
4. Configure:
   - **Table name**: `terraform-locks`
   - **Partition key**: `LockID` (tipo: String)
   - **Table settings**: **On-demand** (Pay per request)
5. Clique em **"Create table"**

**✅ Verificação:**
- Bucket S3 criado em us-east-2
- Tabela DynamoDB criada em us-east-2

---

### 🚀 Opção 3: Criar Backend via AWS CLI

Se você tem AWS CLI configurado e prefere usar linha de comando.

```powershell
# Definir região do backend
$BACKEND_REGION = "us-east-2"

# Criar bucket S3
Write-Host "Criando bucket S3..." -ForegroundColor Yellow
aws s3api create-bucket `
  --bucket meu-terraform-state-bucket-uniqueno `
  --region $BACKEND_REGION `
  --create-bucket-configuration LocationConstraint=$BACKEND_REGION

# Habilitar versionamento
Write-Host "Habilitando versionamento..." -ForegroundColor Yellow
aws s3api put-bucket-versioning `
  --bucket meu-terraform-state-bucket-uniqueno `
  --versioning-configuration Status=Enabled `
  --region $BACKEND_REGION

# Habilitar encriptação
Write-Host "Habilitando encriptação..." -ForegroundColor Yellow
aws s3api put-bucket-encryption `
  --bucket meu-terraform-state-bucket-uniqueno `
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' `
  --region $BACKEND_REGION

# Bloquear acesso público
Write-Host "Bloqueando acesso público..." -ForegroundColor Yellow
aws s3api put-public-access-block `
  --bucket meu-terraform-state-bucket-uniqueno `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" `
  --region $BACKEND_REGION

# Criar tabela DynamoDB
Write-Host "Criando tabela DynamoDB..." -ForegroundColor Yellow
aws dynamodb create-table `
  --table-name terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region $BACKEND_REGION

Write-Host "✅ Backend criado com sucesso!" -ForegroundColor Green
```

**✅ Verificação:**
```powershell
# Verificar bucket
   aws s3 ls --region us-east-2 | Select-String "meu-terraform-state-bucket"

# Verificar tabela
aws dynamodb list-tables --region us-east-2 | Select-String "terraform-locks"
```

---

## 🔐 Configurar Credenciais AWS

### Verificar se já está configurado

```powershell
aws sts get-caller-identity
```

**✅ Se retornar informações da sua conta, está configurado!**

### Configurar credenciais (se necessário)

```powershell
aws configure
```

Você será solicitado a informar:
1. **AWS Access Key ID**: Sua chave de acesso
2. **AWS Secret Access Key**: Sua chave secreta
3. **Default region name**: `sa-east-1` (região principal do projeto)
4. **Default output format**: `json`

**Onde encontrar as credenciais:**
1. Acesse: https://console.aws.amazon.com/iam/
2. Vá em **Users** > Seu usuário > **Security credentials**
3. Clique em **Create access key**
4. Baixe ou copie as credenciais

**⚠️ IMPORTANTE:** As credenciais são salvas em:
- Windows: `C:\Users\SEU_USUARIO\.aws\credentials`
- Linux/Mac: `~/.aws/credentials`

---

## 📝 Preparar Arquivos de Configuração

### 1. Verificar/Criar terraform.tfvars

Navegue para o diretório `infra`:

```powershell
cd "D:\iagob2\fatec  - semestre 6\Computacao em Nuvem II\projeto_testes\projeto_nuvem\infra"
```

Verifique se o arquivo `terraform.tfvars` existe:

```powershell
Get-Content terraform.tfvars
```

**✅ Deve conter algo como:**
```hcl
aws_region     = "sa-east-1"
environment    = "dev"
project_name   = "nuvem"
vpc_cidr       = "10.0.0.0/16"
availability_zones = ["sa-east-1a", "sa-east-1b"]
instance_type  = "t3.micro"
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
db_name        = "tasksdb"
db_username    = "admin"
db_password    = "Admin123!"  # ⚠️ Mude para uma senha segura!
```

**⚠️ IMPORTANTE:**
- A senha do banco deve ter **NO MÍNIMO 8 caracteres**
- Use uma senha forte (letras, números, símbolos)
- **NÃO** commite este arquivo no Git se contiver senhas reais!

### 2. Verificar código da Lambda

Certifique-se de que o código da Lambda existe:

```powershell
cd ..
ls lambda/criar_task/
```

**✅ Deve existir:**
- `index.js` (código da Lambda)
- `package.json` (dependências)

### 3. Criar ZIP da Lambda (se necessário)

Se o ZIP não existir, crie:

```powershell
cd lambda/criar_task

# Instalar dependências
npm install

# Criar diretório build (se não existir)
cd ..\..
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build"
}

# Criar ZIP
Compress-Archive -Path criar_task\* -DestinationPath build\criar_task.zip -Force

# Verificar
ls build\criar_task.zip
```

**✅ O arquivo `build/criar_task.zip` deve existir!**

---

## 🏗️ Deploy da Infraestrutura

Agora que o backend está criado e as configurações estão prontas, vamos fazer o deploy da infraestrutura.

### Passo 1: Navegar para o diretório infra

```powershell
cd "projeto_nuvem\infra"
```

### Passo 2: Inicializar Terraform

```powershell
terraform init  ou terraform init -reconfigure
```

**O que faz:**
- Baixa o provider AWS
- Configura o backend S3 (conecta ao bucket criado anteriormente)
- Prepara o ambiente Terraform

**✅ Saída esperada:**
```
Initializing the backend...
Successfully configured the backend "s3"! Terraform will automatically
use this backend for the plan and apply phases.

Initializing provider plugins...
Terraform has been successfully initialized!
```

**❌ Se aparecer erro sobre backend não encontrado:**
- Verifique se o bucket S3 e tabela DynamoDB foram criados
- Verifique se está na região correta (us-east-2 para o backend)
- Verifique as credenciais AWS

### Passo 3: Importar Recursos ECR Existentes (se necessário)

**⚠️ IMPORTANTE:** Se os repositórios ECR `back-end-nuvem` e `frontend-nuvem` já existirem na AWS (de um deploy anterior), você precisa importá-los antes de executar `terraform apply`.

**Verificar se os repositórios existem:**
```powershell
aws ecr describe-repositories --region sa-east-1 --query 'repositories[?repositoryName==`back-end-nuvem` || repositoryName==`frontend-nuvem`].repositoryName' --output table
```

**Se os repositórios existirem, importe-os:**

**Opção 1: Script Automatizado (RECOMENDADO)**
```powershell
.\import-ecr.ps1
```

**Opção 2: Importar Manualmente**
```powershell
# Importar repositório backend
terraform import aws_ecr_repository.backend back-end-nuvem

# Importar repositório frontend
terraform import aws_ecr_repository.frontend frontend-nuvem
```

**✅ Após importar, continue com o Passo 4.**

### Passo 4: Verificar o plano de execução

```powershell
terraform plan -out=tfplan
```

**O que faz:**
- Mostra todos os recursos que serão criados
- Verifica se há erros de configuração
- Salva o plano em `tfplan`

**⚠️ IMPORTANTE:** Revise cuidadosamente o que será criado! Isso inclui:
- VPC, Subnets, Internet Gateway, Route Tables
- Security Groups
- RDS MySQL (pode levar 10-15 minutos)
- S3 Buckets (para CSVs)
- Lambda Functions
- API Gateway
- ECR Repositories
- ECS Cluster e Services
- IAM Roles e Policies
- Secrets Manager

**⏱️ Tempo estimado:** 1-2 minutos para gerar o plano

### Passo 4: Aplicar as mudanças

```powershell
terraform apply tfplan
```

**Ou para aplicar diretamente (sem salvar plano):**
```powershell
terraform apply
```

Quando perguntar se deseja continuar, digite: `yes`

**O que faz:**
- Cria todos os recursos na AWS
- Pode levar 10-15 minutos (principalmente o RDS)

**⏱️ Tempo estimado:** 10-15 minutos

**⚠️ NOTA IMPORTANTE:** Se você ver um erro sobre `null_resource.create_table` falhando durante o apply, isso é normal e esperado! O script de criação de tabela pode falhar durante o primeiro `terraform apply` porque os outputs ainda não estão disponíveis. O Terraform continuará mesmo com esse erro (o provisioner tem `on_failure = continue`).

Como resolver agora:
cd projeto_nuvem\infra

# Opção 1: Script automatizado (RECOMENDADO)
.\import-ecr.ps1

# Opção 2: Importar manualmente
terraform import aws_ecr_repository.backend back-end-nuvem
terraform import aws_ecr_repository.frontend frontend-nuvem

---- caso tenha um repository no ecr :
aws ecr delete-repository --repository-name frontend-nuvem --force --region sa-east-1

**Após o `terraform apply` completar com sucesso, execute manualmente:**
```powershell
cd projeto_nuvem\infra
.\init-database.ps1
```

**⚠️ CASO DÊ ERRO "VPC ID não encontrado" no script:**

Se o script `init-database.ps1` falhar com erro "VPC ID não encontrado", siga estes passos para obter os valores manualmente e atualizar o script:

1. **Obter os valores do Terraform manualmente:**
   ```powershell
   cd projeto_nuvem\infra
   
   # Obter VPC ID
   terraform output vpc_id
   
   # Obter Subnets privadas
   terraform output private_subnet_ids
   
   # Obter Security Group da Lambda
   terraform output lambda_security_group_id
   
   # Obter Lambda Role ARN
   terraform output lambda_role_arn
   ```

2. **Anotar os valores obtidos** (exemplo do seu ambiente):
   ```
   vpc_id = "vpc-0187c0d7d7df5ff73"
   private_subnet_ids = ["subnet-008d35b42294d27f6", "subnet-0c416190b62249552"]
   lambda_security_group_id = "sg-0f35b2b6f22f18c3a"
   lambda_role_arn = "arn:aws:iam::106343314372:role/nuvem-lambda-role"
   ```

3. **Editar o arquivo `init-database.ps1`** e atualizar os valores fixos:
   ```powershell
   # Abrir o arquivo no editor
   code init-database.ps1
   # ou
   notepad init-database.ps1
   ```
   
   **Localizar e atualizar estas linhas (aproximadamente linha 207-209 e 288):**
   ```powershell
   # Linha ~207: VPC ID - substitua pelo valor obtido
   $VPC_ID = "vpc-0187c0d7d7df5ff73"  # ← Coloque o valor do terraform output vpc_id
   
   # Linha ~208: Subnets - substitua pelos valores obtidos
   $SUBNET_IDS = @("subnet-008d35b42294d27f6", "subnet-0c416190b62249552")  # ← Coloque os valores do terraform output private_subnet_ids
   
   # Linha ~209: Security Group - substitua pelo valor obtido
   $SECURITY_GROUP_ID = "sg-0f35b2b6f22f18c3a"  # ← Coloque o valor do terraform output lambda_security_group_id
   
   # Linha ~288: Lambda Role ARN - substitua pelo valor obtido
   $LAMBDA_ROLE = "arn:aws:iam::106343314372:role/nuvem-lambda-role"  # ← Coloque o valor do terraform output lambda_role_arn
   ```
   
   **💡 Como copiar os valores corretamente:**
   - **VPC ID**: Copie apenas o valor (ex: `vpc-0187c0d7d7df5ff73`) sem as aspas do output
   - **Subnets**: Copie os valores entre colchetes `[]` do output e coloque dentro de `@(...)` no PowerShell
     - Exemplo: Se o output mostrar `["subnet-abc", "subnet-xyz"]`, use `@("subnet-abc", "subnet-xyz")`
   - **Security Group**: Copie apenas o valor (ex: `sg-0f35b2b6f22f18c3a`) sem as aspas
   - **Lambda Role**: Copie o ARN completo (ex: `arn:aws:iam::106343314372:role/nuvem-lambda-role`)

4. **Salvar o arquivo e executar novamente:**
   ```powershell
   .\init-database.ps1
   ```

**💡 DICA:** O script já está configurado com valores fixos (hardcoded) para evitar esse problema. Se você recriar a infraestrutura e os valores mudarem, basta atualizar essas linhas no script com os novos valores do `terraform output`.

**✅ Saída esperada (no final):**
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

Outputs:

api_gateway_invoke_url = "https://abc123xyz.execute-api.sa-east-1.amazonaws.com/dev"
ecr_backend_repository_url = "123456789012.dkr.ecr.sa-east-1.amazonaws.com/back-end-nuvem"
ecr_frontend_repository_url = "123456789012.dkr.ecr.sa-east-1.amazonaws.com/frontend-nuvem"
ecs_cluster_id = "arn:aws:ecs:sa-east-1:123456789012:cluster/nuvem-cluster"
rds_endpoint = "tasks-db.abc123xyz.sa-east-1.rds.amazonaws.com:3306"
s3_bucket_name = "nuvem-csv-bucket-abc123"
```

### Passo 5: Anotar URLs importantes

**💾 SALVE ESTAS URLs!** Você precisará delas nos próximos passos.

```powershell
# Obter URLs dos outputs
terraform output api_gateway_invoke_url
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
terraform output ecs_cluster_id
terraform output rds_endpoint
```

**Ou obter apenas os valores (sem o nome da variável):**
```powershell
$API_GATEWAY_URL = terraform output -raw api_gateway_invoke_url
$ECR_BACKEND_URL = terraform output -raw ecr_backend_repository_url
$ECR_FRONTEND_URL = terraform output -raw ecr_frontend_repository_url
$CLUSTER_ID = terraform output -raw ecs_cluster_id

Write-Host "API Gateway: $API_GATEWAY_URL" -ForegroundColor Cyan
Write-Host "ECR Backend: $ECR_BACKEND_URL" -ForegroundColor Cyan
Write-Host "ECR Frontend: $ECR_FRONTEND_URL" -ForegroundColor Cyan
Write-Host "Cluster ID: $CLUSTER_ID" -ForegroundColor Cyan
```

---

## 🐳 Containerizar e Enviar Backend

Agora vamos criar a imagem Docker do backend e enviá-la para o ECR.

### Passo 1: Verificar Dockerfile do Backend

```powershell
cd ..\back-end
Get-Content Dockerfile
```

**✅ Deve estar assim:**
```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
ENV API_GATEWAY_URL=""
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**✅ Está correto!** A variável `API_GATEWAY_URL` será injetada pelo ECS.

### Passo 2: Build da imagem do Backend

```powershell
# Certifique-se de estar no diretório correto
cd projeto_nuvem\back-end

# Build da imagem
docker build -t back-end-nuvem:latest .

# Verificar se a imagem foi criada
docker images | Select-String "back-end-nuvem"
```

**✅ Saída esperada:**
```
REPOSITORY        TAG       IMAGE ID       CREATED         SIZE
back-end-nuvem    latest    abc123def456   2 minutes ago   150MB
```

**⏱️ Tempo estimado:** 2-5 minutos

### Passo 3: Autenticar no ECR

**No Windows PowerShell (ÚNICO método que funciona):**

```powershell
$AWS_REGION = "sa-east-1"

# Execute este comando (ele faz login automaticamente):
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
```

**✅ Saída esperada:**
```
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Login Succeeded
```

**⚠️ NOTA:** Pode ignorar o aviso. Se aparecer "Login Succeeded", está correto!

**❌ IMPORTANTE:** No Windows PowerShell, NÃO use `aws ecr get-login-password` com `--password-stdin` - esse método não funciona no PowerShell do Windows.

### Passo 4: Fazer Tag da Imagem

```powershell
# Obter URL do repositório diretamente do Terraform
cd ..\infra
$ECR_BACKEND_URL = (terraform output -raw ecr_backend_repository_url).Trim()
cd ..\back-end

# Verificar se a variável foi definida corretamente
Write-Host "URL do repositório: $ECR_BACKEND_URL" -ForegroundColor Cyan

# Fazer tag da imagem
docker tag back-end-nuvem:latest "${ECR_BACKEND_URL}:latest"

# Verificar se o tag funcionou (deve mostrar a imagem tagueada)
docker images | Select-String "back-end-nuvem"
```

**✅ Saída esperada após `docker images`:**
```
106343314372.dkr.ecr.sa-east-1.amazonaws.com/back-end-nuvem   latest    ...
back-end-nuvem                                                latest    ...
```

**Alternativa: Usar URL diretamente (se já anotou no Passo 5):**
```powershell
docker tag back-end-nuvem:latest "106343314372.dkr.ecr.sa-east-1.amazonaws.com/back-end-nuvem:latest"
```

### Passo 5: Enviar para ECR

```powershell
# Se já obteve a variável $ECR_BACKEND_URL acima, use:
docker push "${ECR_BACKEND_URL}:latest"

# OU use a URL diretamente:
docker push "106343314372.dkr.ecr.sa-east-1.amazonaws.com/back-end-nuvem:latest"
```

**✅ Saída esperada:**
```
The push refers to repository [106343314372.dkr.ecr.sa-east-1.amazonaws.com/back-end-nuvem]
0d240e6f8b05: Pushed
317dab709eb2: Pushed
...
latest: digest: sha256:5bd4b8ac01ba... size: 856
```

**✅ Se você vir `digest: sha256:...`, o push foi bem-sucedido!**

**⏱️ Tempo estimado:** 2-5 minutos (dependendo do tamanho da imagem)

### Passo 6: Aguardar Backend Iniciar no ECS

O ECS vai detectar automaticamente a nova imagem e iniciar o container.

```powershell
$CLUSTER_ID = "nuvem-cluster"  # ou use o ARN completo
$AWS_REGION = "sa-east-1"

# Comando em uma linha (RECOMENDADO):
aws ecs describe-services --cluster $CLUSTER_ID --services back-end-service --region $AWS_REGION --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' --output table

# OU use crase invertida (grave accent) para múltiplas linhas:
aws ecs describe-services `
  --cluster $CLUSTER_ID `
  --services back-end-service `
  --region $AWS_REGION `
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' `
  --output table
```

**✅ Aguarde até ver:**
```
Running: 1
Desired: 1
Status: ACTIVE
```

**⏱️ Tempo estimado:** 2-5 minutos

---

## 🎨 Containerizar e Enviar Frontend

O frontend precisa saber a URL do backend para fazer as requisições.

### Passo 1: Decidir qual URL usar

Você tem duas opções:

**Opção A: Frontend chama API Gateway diretamente** (Recomendado)
- ✅ Mais simples
- ✅ Backend não precisa de IP público
- ❌ Frontend não chama o container backend, mas sim o API Gateway

**Opção B: Frontend chama Container Backend diretamente**
- ✅ Mais direto
- ❌ Requer ALB ou IP público do backend
- ❌ Mais complexo

**Para este guia, usaremos a Opção A.**

### Passo 2: Gerar config.js para o Frontend

```powershell
cd projeto_nuvem\infra
$API_GATEWAY_URL = (terraform output -raw api_gateway_invoke_url).Trim().Trim('"')
Write-Host "API Gateway URL: $API_GATEWAY_URL" -ForegroundColor Cyan

cd ..\front-end

# Criar config.js com a URL do API Gateway
$configContent = @"
window.APP_CONFIG = {
  API_URL: '$API_GATEWAY_URL'
};
"@

$configContent | Out-File -FilePath "public\config.js" -Encoding utf8

# Verificar se foi criado
Get-Content public\config.js
```

**✅ Deve conter:**
```javascript
window.APP_CONFIG = {
  API_URL: 'https://abc123xyz.execute-api.sa-east-1.amazonaws.com/dev'
};
```

### Passo 3: Build da imagem do Frontend

```powershell
# Certifique-se de estar no diretório correto
cd projeto_nuvem\front-end

# Build da imagem
docker build -t frontend-nuvem:latest .

# Verificar se a imagem foi criada
docker images | Select-String "frontend-nuvem"
```

**✅ Saída esperada:**
```
REPOSITORY       TAG       IMAGE ID       CREATED         SIZE
frontend-nuvem   latest    def456abc123   1 minute ago    50MB
```

### Passo 4: Autenticar no ECR

```powershell
# Método que funciona no Windows PowerShell:
$AWS_REGION = "sa-east-1"
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
```

**✅ Saída esperada:**
```
Login Succeeded
```

### Passo 5: Obter URL do Repositório ECR do Frontend

```powershell
cd ..\infra

# Obter URL do repositório diretamente do Terraform:
$ECR_FRONTEND_URL = (terraform output -raw ecr_frontend_repository_url).Trim()
Write-Host "ECR Frontend URL: $ECR_FRONTEND_URL" -ForegroundColor Cyan

# Voltar para o diretório do frontend
cd ..\front-end
```

**✅ Se a variável estiver vazia, defina manualmente:**
```powershell
$ECR_FRONTEND_URL = "106343314372.dkr.ecr.sa-east-1.amazonaws.com/frontend-nuvem"
```

### Passo 6: Fazer Tag da Imagem do Frontend

```powershell
# Verificar se a variável foi definida corretamente
Write-Host "Usando URL: $ECR_FRONTEND_URL" -ForegroundColor Cyan

# Fazer tag da imagem
docker tag frontend-nuvem:latest "${ECR_FRONTEND_URL}:latest"

# Verificar se o tag funcionou (deve mostrar a imagem tagueada)
docker images | Select-String "frontend-nuvem"
```

**✅ Saída esperada após `docker images`:**
```
106343314372.dkr.ecr.sa-east-1.amazonaws.com/frontend-nuvem   latest    ...
frontend-nuvem                                                latest    ...
```

### Passo 7: Enviar para ECR

```powershell
# Push para ECR
docker push "${ECR_FRONTEND_URL}:latest"

# OU use a URL diretamente:
docker push "106343314372.dkr.ecr.sa-east-1.amazonaws.com/frontend-nuvem:latest"
```

**✅ Saída esperada:**
```
The push refers to repository [123456789012.dkr.ecr.sa-east-1.amazonaws.com/frontend-nuvem]
...
latest: digest: sha256:def456... size: 567
```

### Passo 8: Aguardar Frontend Iniciar no ECS

```powershell
$CLUSTER_ID = "nuvem-cluster"
$AWS_REGION = "sa-east-1"

aws ecs describe-services `
  --cluster $CLUSTER_ID `
  --services frontend-service `
  --region $AWS_REGION `
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' `
  --output table
```

**✅ Aguarde até ver:**
```
Running: 1
Desired: 1
Status: ACTIVE
```

### Passo 9: Obter IP Público do Frontend

O frontend está em subnet pública, então tem IP público:

```powershell
# Listar tasks do frontend:
$TASK_ARN = aws ecs list-tasks `
  --cluster $CLUSTER_ID `
  --service-name frontend-service `
  --region $AWS_REGION `
  --query 'taskArns[0]' `
  --output text

# Obter Network Interface ID:
$ENI_ID = aws ecs describe-tasks `
  --cluster $CLUSTER_ID `
  --tasks $TASK_ARN `
  --region $AWS_REGION `
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' `
  --output text

# Obter IP público:
$FRONTEND_IP = aws ec2 describe-network-interfaces `
  --network-interface-ids $ENI_ID `
  --region $AWS_REGION `
  --query 'NetworkInterfaces[0].Association.PublicIp' `
  --output text

Write-Host "Frontend URL: http://$FRONTEND_IP" -ForegroundColor Green
```

**✅ Anote o IP público!** É a URL para acessar o frontend: `http://54.233.235.180`

---

## 🗄️ Criar Tabela no Banco de Dados

**⚠️ CRÍTICO:** ANTES de testar a API, você PRECISA criar a tabela `tasks` no MySQL!

### ✅ Opção 1: Script Automático PowerShell (RECOMENDADO)

**Este script cria a tabela automaticamente via Lambda temporária!**

```powershell
# Execute após o terraform apply:
cd projeto_nuvem\infra

# Execute o script:
.\init-database.ps1
```

**O que o script faz:**
1. ✅ Obtém informações do RDS via `terraform output`
2. ✅ Obtém credenciais do Secrets Manager
3. ✅ Cria uma Lambda temporária que executa o SQL
4. ✅ Invoca a Lambda para criar a tabela
5. ✅ Remove a Lambda temporária

**✅ Saída esperada:**
```
=== Criando tabela 'tasks' no RDS automaticamente ===

✅ Informações obtidas
✅ Credenciais obtidas
✅ Lambda criada com sucesso
✅ Tabela criada com sucesso!
```

**⚠️ Requisitos:**
- Node.js e npm instalados (para criar o ZIP da Lambda)
- AWS CLI configurado
- Terraform já aplicado (RDS deve estar `available`)

**⚠️ CASO DÊ ERRO "VPC ID não encontrado":**

Se o script falhar ao obter os valores do Terraform, você pode obter os valores manualmente e atualizar o script:

1. **Obter os valores do Terraform:**
   ```powershell
   cd projeto_nuvem\infra
   
   # Obter VPC ID
   terraform output vpc_id
   
   # Obter Subnets privadas
   terraform output private_subnet_ids
   
   # Obter Security Group da Lambda
   terraform output lambda_security_group_id
   
   # Obter Lambda Role ARN
   terraform output lambda_role_arn
   ```

2. **Anotar os valores obtidos** (exemplo):
   ```
   vpc_id = "vpc-0187c0d7d7df5ff73"
   private_subnet_ids = ["subnet-008d35b42294d27f6", "subnet-0c416190b62249552"]
   lambda_security_group_id = "sg-0f35b2b6f22f18c3a"
   lambda_role_arn = "arn:aws:iam::106343314372:role/nuvem-lambda-role"
   ```

3. **Editar o arquivo `init-database.ps1`** e atualizar os valores fixos:
   ```powershell
   # Abrir o arquivo no editor
   code init-database.ps1
   # ou
   notepad init-database.ps1
   ```
   
   **Localizar e atualizar estas linhas (aproximadamente linha 207-209 e 288):**
   ```powershell
   # Linha ~207: VPC ID
   $VPC_ID = "vpc-0187c0d7d7df5ff73"  # ← Coloque o valor obtido do terraform output
   
   # Linha ~208: Subnets (array com os IDs)
   $SUBNET_IDS = @("subnet-008d35b42294d27f6", "subnet-0c416190b62249552")  # ← Coloque os valores obtidos
   
   # Linha ~209: Security Group
   $SECURITY_GROUP_ID = "sg-0f35b2b6f22f18c3a"  # ← Coloque o valor obtido
   
   # Linha ~288: Lambda Role ARN
   $LAMBDA_ROLE = "arn:aws:iam::106343314372:role/nuvem-lambda-role"  # ← Coloque o valor obtido
   ```

4. **Salvar o arquivo e executar novamente:**
   ```powershell
   .\init-database.ps1
   ```

**💡 DICA:** O script já está configurado com valores fixos (hardcoded) para evitar esse problema. Se você recriar a infraestrutura e os valores mudarem, basta atualizar essas linhas no script com os novos valores do `terraform output`.

### Opção 2: Via AWS RDS Query Editor (Manual)

Se o script automático não funcionar, use o RDS Query Editor:

1. Acesse: https://console.aws.amazon.com/rds/?region=sa-east-1
2. **⚠️ IMPORTANTE:** Certifique-se de estar na região **São Paulo (sa-east-1)**, não em Ohio!
3. Vá em **Databases** > Selecione `tasks-db`
4. Clique em **Query Editor** (ou **Actions** > **Connect**)
5. Entre com as credenciais do Secrets Manager:
   ```powershell
   cd projeto_nuvem\infra
   $SECRET_ARN = terraform output -raw rds_secret_arn
   aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region sa-east-1 --query SecretString --output text | ConvertFrom-Json
   ```
6. Cole o SQL abaixo:

```sql
CREATE DATABASE IF NOT EXISTS tasksdb;
USE tasksdb;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

7. Execute o query
8. **✅ Tabela criada!**

---

## 🧪 Testar a Aplicação

### 1. Testar API Gateway

**Opção A: Usar Script Automatizado (RECOMENDADO)**

```powershell
cd projeto_nuvem\scripts
.\testar-api-windows.ps1
```

**O que o script faz:**
- Obtém URL do API Gateway automaticamente
- Testa GET /tasks
- Testa POST /tasks
- Mostra resultados formatados

**Opção B: Testar Manualmente**

```powershell
cd projeto_nuvem\infra
$API_GATEWAY_URL = (terraform output -raw api_gateway_invoke_url).Trim().Trim('"')
Write-Host "API Gateway URL: $API_GATEWAY_URL" -ForegroundColor Cyan

# 1. Listar tasks (GET /tasks)
try {
    $result = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method GET
    $result | ConvertTo-Json -Depth 5
    Write-Host "✅ GET /tasks funcionou!" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro ao buscar tasks:" -ForegroundColor Red
    $_.Exception.Message
}

# 2. Criar task (POST /tasks)
$body = @{
    title = "Teste PowerShell"
    description = "Teste de API via PowerShell no Windows"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "$API_GATEWAY_URL/tasks" -Method POST -Body $body -ContentType "application/json"
    $result | ConvertTo-Json -Depth 5
    Write-Host "✅ Task criada com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro ao criar task:" -ForegroundColor Red
    $_.Exception.Message
}
```

**✅ Deve retornar JSON com as tasks ou confirmação de criação.**

**❌ Se receber erro `"Table 'tasksdb.tasks' doesn't exist"`:**
- **Solução:** Execute a seção acima "Criar Tabela no Banco de Dados"

### 2. Testar Frontend

Abra no navegador:
```
http://IP_PUBLICO_DO_FRONTEND 
```

**✅ Você deve ver:**
- Interface do gerenciador de tasks
- Lista de tasks (se houver)
- Botão para adicionar nova task

**🔍 Se não aparecer nada:**
1. Abra o Console do Navegador (F12)
2. Verifique erros de conexão
3. Verifique se `config.js` foi carregado corretamente
4. Verifique os logs do frontend no CloudWatch

---

## 📜 Scripts Disponíveis

O projeto inclui vários scripts PowerShell para automatizar tarefas comuns:

### 1. `scripts/deploy-completo.ps1`

**O que faz:** Deploy completo automatizado
- Deploy da infraestrutura com Terraform
- Build e push do backend
- Build e push do frontend
- Atualização dos serviços ECS

**Uso:**
```powershell
cd projeto_nuvem\scripts
.\deploy-completo.ps1
```

**Parâmetros:**
```powershell
.\deploy-completo.ps1 -AWS_REGION "sa-east-1"
```

### 2. `scripts/testar-api-windows.ps1`

**O que faz:** Testa a API Gateway automaticamente
- Obtém URL do API Gateway via Terraform
- Testa GET /tasks
- Testa POST /tasks
- Mostra resultados formatados

**Uso:**
```powershell
cd projeto_nuvem\scripts
.\testar-api-windows.ps1
```

### 3. `infra/init-database.ps1`

**O que faz:** Cria a tabela `tasks` no RDS automaticamente
- Obtém informações do RDS via Terraform
- Obtém credenciais do Secrets Manager
- Cria Lambda temporária
- Executa SQL para criar tabela
- Remove Lambda temporária

**Uso:**
```powershell
cd projeto_nuvem\infra
.\init-database.ps1
```

### 4. Outros Scripts

- `scripts/testar-tudo.ps1`: Executa todos os testes
- `scripts/reset-tudo.ps1`: Reseta o ambiente
- `scripts/reset-completo.ps1`: Reset completo

---

## 🐛 Troubleshooting

### Erro: "Backend não encontrado" no terraform init

**Causa 1:** Bucket S3 ou tabela DynamoDB não existem.

**Solução:**
1. Verifique se o bucket existe:
   ```powershell
   aws s3 ls --region us-east-2 | Select-String "meu-terraform-state-bucket"
   ```
2. Verifique se a tabela existe:
   ```powershell
   aws dynamodb list-tables --region us-east-2 | Select-String "terraform-locks"
   ```
3. Se não existirem, crie usando uma das opções na seção "Criar Backend S3 e DynamoDB"

**Causa 2:** O bucket existe, mas o nome não corresponde ao configurado no `backend.tf`.

**Erro típico:**
```
Error: Failed to get existing workspaces: S3 bucket "meu-terraform-state-bucket-uniqueno" does not exist.
```

**Solução:**
1. Verifique o nome exato do bucket criado:
   ```powershell
   aws s3 ls --region us-east-2
   ```
   Você verá algo como: `meu-terraform-state-bucket-uniqueno21` (com sufixo "21")

2. Atualize o arquivo `infra/backend.tf` para usar o nome correto:
   ```powershell
   cd projeto_nuvem\infra
   # Edite backend.tf e altere a linha do bucket para o nome real
   ```
   
   **Exemplo:** Se o bucket se chama `meu-terraform-state-bucket-uniqueno21`, altere:
   ```hcl
   bucket = "meu-terraform-state-bucket-uniqueno21"  # Nome correto do bucket
   ```

3. Tente novamente:
   ```powershell
   terraform init
   ```

**⚠️ IMPORTANTE:** O nome do bucket no `backend.tf` deve ser EXATAMENTE igual ao nome do bucket criado na AWS!

### Erro: "RepositoryAlreadyExistsException" no terraform apply

**Causa:** Os repositórios ECR `back-end-nuvem` e `frontend-nuvem` já existem na AWS, mas o Terraform está tentando criá-los novamente.

**Erro típico:**
```
Error: creating ECR Repository (back-end-nuvem): RepositoryAlreadyExistsException: 
The repository with name 'back-end-nuvem' already exists
```

**Solução:** Importe os repositórios existentes para o estado do Terraform:

**Opção 1: Usar Script Automatizado (RECOMENDADO)**
```powershell
cd projeto_nuvem\infra
.\import-ecr.ps1
```

**Opção 2: Importar Manualmente**
```powershell
cd projeto_nuvem\infra

# Importar repositório backend
terraform import aws_ecr_repository.backend back-end-nuvem

# Importar repositório frontend
terraform import aws_ecr_repository.frontend frontend-nuvem

# Verificar se funcionou
terraform plan
```

**✅ Após importar, execute `terraform apply` novamente.**

### Erro: "Repository does not exist" no docker push

**Causa:** ECR não foi criado ou URL incorreta.

**Solução:**
```powershell
# Verificar se o repositório existe
aws ecr describe-repositories --region sa-east-1

# Verificar a URL correta
cd projeto_nuvem\infra
terraform output ecr_backend_repository_url
```

### Erro: "Login failed" ou "400 Bad Request" no ECR

**Causa 1:** Credenciais AWS inválidas ou expiradas.

**Solução:**
```powershell
# Verificar credenciais
aws sts get-caller-identity

# Reconfigurar credenciais
aws configure
```

**Causa 2:** No Windows PowerShell, o método `--password-stdin` pode não funcionar.

**Solução:** Use o método que funciona no Windows:
```powershell
$AWS_REGION = "sa-east-1"
aws ecr get-login --region $AWS_REGION --no-include-email | Invoke-Expression
```

### Erro: "No tasks found" no ECS

**Causa:** Imagem não existe no ECR ou Task Definition incorreta.

**Solução:**
```powershell
# Verificar se a imagem existe
aws ecr describe-images --repository-name back-end-nuvem --region sa-east-1

# Verificar Task Definition
aws ecs describe-task-definition --task-definition back-end-nuvem --region sa-east-1 --query 'taskDefinition.containerDefinitions[0].image'
```

### Erro: "Table 'tasksdb.tasks' doesn't exist"

**Causa:** Tabela não foi criada no banco de dados.

**Solução:**
1. Execute o script automático:
   ```powershell
   cd projeto_nuvem\infra
   .\init-database.ps1
   ```
2. Ou crie manualmente via RDS Query Editor (veja seção "Criar Tabela no Banco de Dados")

### Erro: "local-exec provisioner error" no null_resource.create_table

**Causa:** O script `init-database.ps1` está tentando executar durante o `terraform apply`, mas os outputs ainda não estão disponíveis.

**Erro típico:**
```
Error: local-exec provisioner error
Error running command 'powershell.exe -ExecutionPolicy Bypass -File ./init-database.ps1': exit status 1
```

**Solução:** Este erro é esperado e não impede o `terraform apply` de continuar (o provisioner tem `on_failure = continue`). Após o `terraform apply` completar com sucesso:

1. Execute o script manualmente:
   ```powershell
   cd projeto_nuvem\infra
   .\init-database.ps1
   ```

2. O script agora terá acesso aos outputs do Terraform e criará a tabela corretamente.

**✅ Isso é normal!** O script é executado automaticamente, mas pode falhar na primeira vez. Execute manualmente após o primeiro `terraform apply`.

### Erro: "VPC ID não encontrado" no init-database.ps1

**Causa:** O Terraform não está retornando os outputs corretamente, ou os outputs não foram atualizados após o `terraform apply`.

**Erro típico:**
```
❌ ERRO: Não foi possível obter VPC ID do Terraform!
VPC ID não encontrado
```

**Solução:**

1. **Atualizar os outputs do Terraform:**
   ```powershell
   cd projeto_nuvem\infra
   terraform refresh
   ```

2. **Verificar se os outputs estão disponíveis:**
   ```powershell
   terraform output vpc_id
   terraform output private_subnet_ids
   terraform output lambda_security_group_id
   ```

3. **Se os outputs não aparecerem, execute um apply novamente (não vai mudar nada, só atualiza os outputs):**
   ```powershell
   terraform apply
   # Digite 'yes' quando perguntar
   ```

4. **Verificar se os outputs existem no arquivo `outputs.tf`:**
   - `output "vpc_id"` deve existir
   - `output "private_subnet_ids"` deve existir
   - `output "lambda_security_group_id"` deve existir

5. **Se tudo estiver correto, execute o script novamente:**
   ```powershell
   .\init-database.ps1
   ```

**✅ Os outputs já estão definidos no `outputs.tf`!** O problema geralmente é que o Terraform precisa de um `refresh` ou `apply` para atualizar os valores.

### Frontend não carrega

**Causa:** IP público incorreto ou Security Group bloqueando.

**Solução:**
1. Verificar Security Group do frontend:
   ```powershell
   aws ec2 describe-security-groups --filters "Name=tag:Name,Values=nuvem-frontend*" --region sa-east-1 --query 'SecurityGroups[0].{GroupId:GroupId,Ingress:IpPermissions}'
   ```
2. Deve permitir tráfego na porta 80 (HTTP) de `0.0.0.0/0`

### Backend não conecta ao API Gateway

**Causa:** Variável de ambiente `API_GATEWAY_URL` não foi injetada.

**Solução:**
1. Verificar Task Definition:
   ```powershell
   aws ecs describe-task-definition --task-definition back-end-nuvem --region sa-east-1 --query 'taskDefinition.containerDefinitions[0].environment'
   ```
2. Deve conter `API_GATEWAY_URL` com a URL do API Gateway.

### Erro: "Lambda ZIP não encontrado"

**Causa:** Arquivo `build/criar_task.zip` não existe.

**Solução:**
```powershell
cd projeto_nuvem\lambda\criar_task
npm install
cd ..\..
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build"
}
Compress-Archive -Path criar_task\* -DestinationPath build\criar_task.zip -Force
```

### Erro: "RDS não pode ser criado"

**Causa:** Senha no `terraform.tfvars` não atende aos requisitos do MySQL.

**Solução:**
- A senha deve ter **NO MÍNIMO 8 caracteres**
- Use uma senha forte (letras, números, símbolos)
- Edite `infra/terraform.tfvars` e ajuste `db_password`

---

## 📊 Resumo dos Comandos Principais

### Criar Backend
```powershell
# Opção 1: Terraform (recomendado)
# Veja seção "Criar Backend S3 e DynamoDB - Opção 1"

# Opção 2: AWS Console
# Veja seção "Criar Backend S3 e DynamoDB - Opção 2"

# Opção 3: AWS CLI
# Veja seção "Criar Backend S3 e DynamoDB - Opção 3"
```

### Deploy Infraestrutura
```powershell
cd projeto_nuvem\infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Deploy Backend
```powershell
cd projeto_nuvem\back-end
docker build -t back-end-nuvem:latest .
aws ecr get-login --region sa-east-1 --no-include-email | Invoke-Expression
$ECR_BACKEND_URL = (cd ..\infra; terraform output -raw ecr_backend_repository_url).Trim()
docker tag back-end-nuvem:latest "${ECR_BACKEND_URL}:latest"
docker push "${ECR_BACKEND_URL}:latest"
```

### Deploy Frontend
```powershell
cd projeto_nuvem\front-end
$API_GATEWAY_URL = (cd ..\infra; terraform output -raw api_gateway_invoke_url).Trim().Trim('"')
@"
window.APP_CONFIG = {
  API_URL: '$API_GATEWAY_URL'
};
"@ | Out-File -FilePath "public\config.js" -Encoding utf8
docker build -t frontend-nuvem:latest .
aws ecr get-login --region sa-east-1 --no-include-email | Invoke-Expression
$ECR_FRONTEND_URL = (cd ..\infra; terraform output -raw ecr_frontend_repository_url).Trim()
docker tag frontend-nuvem:latest "${ECR_FRONTEND_URL}:latest"
docker push "${ECR_FRONTEND_URL}:latest"
```

### Criar Tabela no Banco
```powershell
cd projeto_nuvem\infra
.\init-database.ps1
```

### Testar API
```powershell
cd projeto_nuvem\scripts
.\testar-api-windows.ps1
```

---

## 📝 Checklist Final

Antes de considerar o deploy completo, verifique:

- [ ] Backend S3 e DynamoDB criados
- [ ] Credenciais AWS configuradas
- [ ] Arquivo `terraform.tfvars` criado
- [ ] ZIP da Lambda criado (`build/criar_task.zip`)
- [ ] Infraestrutura criada com Terraform
- [ ] Backend buildado e enviado para ECR
- [ ] Backend rodando no ECS (1/1 tasks)
- [ ] Frontend buildado com `config.js` correto
- [ ] Frontend enviado para ECR
- [ ] Frontend rodando no ECS (1/1 tasks)
- [ ] Tabela `tasks` criada no banco de dados
- [ ] API Gateway respondendo
- [ ] Frontend acessível via IP público
- [ ] Frontend consegue listar/criar tasks

---

## 🗑️ Destruir a Infraestrutura

**⚠️ CUIDADO:** Isso apaga TODOS os recursos criados!

```powershell
cd projeto_nuvem\infra
terraform destroy -auto-approve
```

**⚠️ IMPORTANTE:** 
- O backend S3 e DynamoDB NÃO serão destruídos (estão em outro projeto/região)
- Todos os outros recursos serão removidos
- Isso é IRREVERSÍVEL!

---

**🎉 Parabéns! Seu projeto está na nuvem!**

Para mais detalhes, consulte:
- `infra/GUIA-USO-INFRAESTRUTURA.md` - Documentação detalhada da infraestrutura
- `infra/README.md` - Documentação da infraestrutura
- `infra/SETUP-BACKEND.md` - Guia específico do backend (referência)

**Última atualização:** 2024
