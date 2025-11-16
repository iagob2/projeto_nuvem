# Setup do Backend Terraform - Passo a Passo

## 📋 Pré-requisitos

Antes de executar `terraform init` no projeto principal, você precisa criar:

1. **Bucket S3**: `meu-terraform-state-bucket-uniqueno`
2. **Tabela DynamoDB**: `terraform-locks`

Ambos na região **sa-east-1**.

---

## 🚀 Opção 1: Usando Terraform (Recomendado)

### Passo 1: Criar o Backend

1. **Crie um diretório temporário** (fora do projeto principal):
   ```powershell
   mkdir terraform-backend-setup
   cd terraform-backend-setup
   ```

2. **Copie o arquivo de setup**:
   ```powershell
   copy ..\infra\setup-backend.tf .
   ```

3. **Inicialize o Terraform** (sem backend):
   ```powershell
   terraform init
   ```

4. **Verifique o que será criado**:
   ```powershell
   terraform plan
   ```

5. **Crie os recursos**:
   ```powershell
   terraform apply
   ```

6. **Após criar, volte para o projeto principal**:
   ```powershell
   cd ..\infra
   terraform init  # Agora pode usar o backend
   ```

---

## 🚀 Opção 2: Usando AWS Console (Manual)

### Criar Bucket S3

1. Acesse: https://console.aws.amazon.com/s3/
2. Clique em **"Create bucket"**
3. Configure:
   - **Bucket name**: `meu-terraform-state-bucket-uniqueno`
   - **Region**: `South America (São Paulo) - sa-east-1`
   - **Block Public Access**: ✅ Habilitar tudo
   - **Versioning**: ✅ Habilitar
   - **Encryption**: ✅ AES256
4. Clique em **"Create bucket"**

### Criar Tabela DynamoDB

1. Acesse: https://console.aws.amazon.com/dynamodb/
2. Clique em **"Create table"**
3. Configure:
   - **Table name**: `terraform-locks`
   - **Partition key**: `LockID` (tipo: String)
   - **Table settings**: **On-demand** (Pay per request)
   - **Region**: `sa-east-1`
4. Clique em **"Create table"**

---

## 🚀 Opção 3: Usando AWS CLI (Se tiver instalado)

```powershell
# Criar bucket S3
aws s3api create-bucket `
  --bucket meu-terraform-state-bucket-uniqueno `
  --region sa-east-1 `
  --create-bucket-configuration LocationConstraint=sa-east-1

# Habilitar versionamento
aws s3api put-bucket-versioning `
  --bucket meu-terraform-state-bucket-uniqueno `
  --versioning-configuration Status=Enabled

# Habilitar encriptação
aws s3api put-bucket-encryption `
  --bucket meu-terraform-state-bucket-uniqueno `
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Criar tabela DynamoDB
aws dynamodb create-table `
  --table-name terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region sa-east-1
```

---

## ✅ Verificação

Após criar os recursos, verifique se existem:

1. **Bucket S3**: `meu-terraform-state-bucket-uniqueno` em sa-east-1
2. **Tabela DynamoDB**: `terraform-locks` em sa-east-1

---

## 🔄 Próximos Passos

Depois de criar o backend:

1. Volte para o diretório `infra`
2. Execute `terraform init`
3. O Terraform detectará o backend automaticamente
4. Execute `terraform plan` e `terraform apply`

---

## ⚠️ Importante

- O bucket S3 deve ter um nome **único globalmente** (não pode existir outro bucket com o mesmo nome)
- Se o nome já existir, altere no `backend.tf` antes de criar
- A tabela DynamoDB também precisa ter um nome único na sua conta AWS

---

**Última atualização:** 2024

