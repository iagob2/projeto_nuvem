# 🔄 Reset Completo - Começar do Zero

Este guia explica como destruir TODOS os recursos e começar do zero.

## ⚠️ ATENÇÃO

**ISSO VAI DESTRUIR:**
- ✅ VPC, Subnets, NAT Gateways
- ✅ RDS MySQL Database (e todos os dados!)
- ✅ Lambda Functions
- ✅ API Gateway
- ✅ ECS Cluster, Services e Task Definitions
- ✅ ECR Repositories (mas as imagens Docker podem ficar)
- ✅ S3 Buckets (e todos os arquivos!)
- ✅ Security Groups
- ✅ Secrets Manager Secrets
- ✅ EC2 Instances
- ✅ IAM Roles e Policies

## 🚀 Opção 1: Reset Automático (Recomendado)

### Passo 1: Remover o Secret Manualmente (Importante!)

O Secret Manager pode causar problemas. Remova primeiro:

```powershell
cd projeto_nuvem\infra

# Verificar se o secret existe
aws secretsmanager describe-secret --secret-id nuvem-rds-credentials --region sa-east-1

# Remover completamente (force delete)
aws secretsmanager delete-secret --secret-id nuvem-rds-credentials --force-delete-without-recovery --region sa-east-1

# Aguardar 30 segundos
Start-Sleep -Seconds 30
```

### Passo 2: Executar o Script de Reset

```powershell
.\reset-completo.ps1
```

O script vai:
1. Pedir confirmação (digite `DESTRUIR`)
2. Remover locks
3. Executar `terraform destroy -auto-approve`
4. Destruir todos os recursos

## 🔧 Opção 2: Reset Manual

### Passo 1: Remover Locks

```powershell
cd projeto_nuvem\infra

# Remover lock (use o ID do erro que aparecer)
terraform force-unlock -force <LOCK_ID>
```

### Passo 2: Remover Secret

```powershell
aws secretsmanager delete-secret --secret-id nuvem-rds-credentials --force-delete-without-recovery --region sa-east-1
Start-Sleep -Seconds 30
```

### Passo 3: Destruir Recursos

```powershell
terraform destroy
# Digite 'yes' quando perguntar
```

### Passo 4: Limpar State (Opcional)

Se o `terraform destroy` não funcionar completamente:

```powershell
# Limpar state local
.\limpar-state-manual.ps1

# OU limpar manualmente:
# 1. S3: Deletar arquivo terraform.tfstate do bucket
# 2. DynamoDB: Deletar item do lock na tabela terraform-locks
```

## 📋 Opção 3: Reset Completo (Incluindo State Remoto)

Se nada funcionar, limpe TUDO:

### 1. Remover Secret

```powershell
aws secretsmanager delete-secret --secret-id nuvem-rds-credentials --force-delete-without-recovery --region sa-east-1
```

### 2. Limpar State Remoto no S3

```powershell
# Listar arquivos
aws s3 ls s3://meu-terraform-state-bucket-uniqueno/tasks-architecture/ --region sa-east-1

# Deletar state
aws s3 rm s3://meu-terraform-state-bucket-uniqueno/tasks-architecture/terraform.tfstate --region sa-east-1
```

### 3. Limpar Locks no DynamoDB

```powershell
# Listar locks
aws dynamodb scan --table-name terraform-locks --region sa-east-1

# Deletar lock (criar arquivo delete-key.json primeiro)
# Conteúdo do arquivo delete-key.json:
# {"LockID":{"S":"meu-terraform-state-bucket-uniqueno/tasks-architecture/terraform.tfstate"}}

aws dynamodb delete-item --table-name terraform-locks --key file://delete-key.json --region sa-east-1
```

### 4. Destruir Recursos (se ainda existirem)

Via AWS Console ou CLI, remova manualmente:
- RDS Instances
- ECS Services e Clusters
- Lambda Functions
- API Gateway
- VPC e recursos de rede
- EC2 Instances

### 5. Reinicializar Terraform

```powershell
terraform init -reconfigure
terraform plan
```

## ✅ Depois do Reset

1. **Inicializar Terraform novamente:**
   ```powershell
   terraform init
   ```

2. **Verificar se está tudo limpo:**
   ```powershell
   terraform state list
   # Deve estar vazio ou só ter recursos do backend
   ```

3. **Criar tudo novamente:**
   ```powershell
   terraform plan
   terraform apply
   ```

## 🔍 Verificar se Recursos Foram Removidos

```powershell
# Verificar RDS
aws rds describe-db-instances --region sa-east-1 | Select-String "tasks-db"

# Verificar Lambda
aws lambda list-functions --region sa-east-1 | Select-String "CriarTask|ListarTasks|ObterTaskPorId|SalvarCSV"

# Verificar ECS
aws ecs list-clusters --region sa-east-1
aws ecs list-services --cluster nuvem-cluster --region sa-east-1

# Verificar API Gateway
aws apigateway get-rest-apis --region sa-east-1 | Select-String "tasks-api"

# Verificar Secrets
aws secretsmanager list-secrets --region sa-east-1 | Select-String "rds-credentials"
```

---

## 💡 Dica

Se você tem recursos importantes que não quer perder:
1. Faça backup dos dados do RDS antes de destruir
2. Faça backup dos arquivos do S3
3. Anote as URLs do API Gateway
4. Exporte as configurações do ECS

