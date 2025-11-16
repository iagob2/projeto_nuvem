# Guia de Deploy - Passo a Passo

## 📋 Pré-requisitos Verificados

- ✅ Backend S3 e DynamoDB criados manualmente
- ✅ Credenciais AWS configuradas em `C:\Users\iagoc\.aws\credentials`
- ✅ Arquivo `terraform.tfvars` criado
- ✅ Código da Lambda criado em `lambda/criar_task/`
- ✅ Dependências npm instaladas
- ✅ ZIP da Lambda criado em `build/criar_task.zip`

---

## 🚀 Passo a Passo de Deploy

### 1. Verificar se Terraform está instalado

```powershell
terraform version
```

Se não estiver instalado, baixe em: https://www.terraform.io/downloads

### 2. Navegar para o diretório infra

```powershell
cd infra
```

### 3. Inicializar Terraform

```powershell
terraform init
```

**O que faz:**
- Baixa o provider AWS
- Configura o backend S3
- Prepara o ambiente Terraform

**Esperado:** Deve conectar ao bucket S3 e tabela DynamoDB criados manualmente.

### 4. Verificar o plano de execução

```powershell
terraform plan -out=tfplan
```

**O que faz:**
- Mostra todos os recursos que serão criados
- Verifica se há erros
- Salva o plano em `tfplan`

**Importante:** Revise cuidadosamente o que será criado!

### 5. Aplicar as mudanças

```powershell
terraform apply tfplan
```

**O que faz:**
- Cria todos os recursos na AWS:
  - VPC, Subnets, Gateways
  - Security Groups
  - RDS MySQL
  - S3 Buckets
  - Lambda Functions
  - API Gateway
  - IAM Roles e Policies

**Tempo estimado:** 10-15 minutos

### 6. Ver os outputs

```powershell
terraform output
```

**Outputs importantes:**
- `rds_endpoint`: Endpoint do banco de dados
- `s3_bucket_name`: Nome do bucket CSV
- `api_gateway_invoke_url`: URL da API

---

## 🧪 Testar a API

### Obter a URL da API

```powershell
terraform output api_gateway_invoke_url
```

### Criar uma Task (POST)

```powershell
$url = terraform output -raw api_gateway_invoke_url
Invoke-RestMethod -Uri "$url/tasks" -Method POST -Body (@{title="Minha primeira task"; description="Teste"} | ConvertTo-Json) -ContentType "application/json"
```

### Listar Tasks (GET)

```powershell
Invoke-RestMethod -Uri "$url/tasks" -Method GET
```

---

## 🗑️ Destruir a Infraestrutura

**CUIDADO:** Isso apaga TODOS os recursos criados!

```powershell
terraform destroy -auto-approve
```

---

## 📝 Notas Importantes

### Antes de aplicar:

1. **Verifique a senha do banco** em `terraform.tfvars`
2. **Revise o `terraform plan`** cuidadosamente
3. **Certifique-se** de que o bucket S3 e DynamoDB existem

### Durante o apply:

- O RDS pode levar 5-10 minutos para ser criado
- A Lambda será criada automaticamente com o ZIP de `build/criar_task.zip`
- O API Gateway será deployado automaticamente

### Após o apply:

1. **Crie a tabela no banco** (se necessário):
   ```sql
   CREATE TABLE tasks (
     id INT AUTO_INCREMENT PRIMARY KEY,
     title VARCHAR(255) NOT NULL,
     description TEXT,
     status VARCHAR(50) DEFAULT 'pending',
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

2. **Teste a API** usando a URL do output

---

## 🆘 Troubleshooting

### Erro: Backend não encontrado
**Solução:** Verifique se o bucket S3 e tabela DynamoDB existem na região sa-east-1

### Erro: Credenciais não encontradas
**Solução:** Verifique `C:\Users\iagoc\.aws\credentials`

### Erro: Lambda ZIP não encontrado
**Solução:** Certifique-se de que `build/criar_task.zip` existe

### Erro: RDS não pode ser criado
**Solução:** Verifique se a senha no `terraform.tfvars` atende aos requisitos do MySQL



