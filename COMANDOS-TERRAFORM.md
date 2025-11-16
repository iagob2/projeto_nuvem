# Comandos Terraform - Guia Rápido

## 📋 Ordem de Execução

### 1. Inicializar Terraform

```powershell
cd infra
terraform init
```

**O que faz:**
- Baixa o provider AWS
- Configura o backend S3 (conecta ao bucket criado manualmente)
- Prepara o ambiente

**Tempo:** ~30 segundos

---

### 2. Verificar o Plano

```powershell
terraform plan -out=tfplan
```

**O que faz:**
- Analisa todos os arquivos `.tf`
- Mostra o que será criado/modificado/destruído
- Salva o plano em `tfplan` para aplicar depois

**Importante:** 
- ✅ Revise cuidadosamente antes de aplicar
- ✅ Verifique se os recursos estão corretos
- ✅ Confirme que a senha do banco está correta

**Tempo:** ~1-2 minutos

---

### 3. Aplicar as Mudanças

```powershell
terraform apply tfplan
```

**OU** (sem salvar o plano):

```powershell
terraform apply
```

**O que faz:**
- Cria todos os recursos na AWS:
  1. VPC e Networking (~2 min)
  2. Security Groups (~30 seg)
  3. IAM Roles e Policies (~30 seg)
  4. S3 Buckets (~1 min)
  5. Secrets Manager (~30 seg)
  6. RDS MySQL (~10-15 min) ⏱️ **Mais demorado**
  7. Lambda Functions (~2 min)
  8. API Gateway (~1 min)

**Tempo total:** ~15-20 minutos

**Durante o apply:**
- Você verá o progresso de cada recurso
- O RDS é o mais demorado (criação da instância)
- Pode ser interrompido com `Ctrl+C` (mas não recomendado)

---

### 4. Ver os Outputs

```powershell
terraform output
```

**Outputs principais:**
- `rds_endpoint`: Endpoint do banco (ex: `tasks-db.xxxxx.rds.amazonaws.com:3306`)
- `s3_bucket_name`: Nome do bucket CSV
- `api_gateway_invoke_url`: URL da API (ex: `https://xxxxx.execute-api.sa-east-1.amazonaws.com/dev`)

**Ver um output específico:**
```powershell
terraform output api_gateway_invoke_url
terraform output rds_endpoint
```

---

### 5. Criar a Tabela no Banco

Após o RDS ser criado, você precisa criar a tabela `tasks`:

**Opção A: Via MySQL Client (se tiver instalado)**

```powershell
mysql -h <rds_endpoint> -u admin -p tasksdb < lambda/criar_task/create_table.sql
```

**Opção B: Via AWS RDS Query Editor (Console)**

1. Acesse: https://console.aws.amazon.com/rds/
2. Selecione sua instância RDS
3. Clique em "Query Editor"
4. Cole o conteúdo de `lambda/criar_task/create_table.sql`
5. Execute

**Opção C: Via Lambda (temporário)**

Crie uma Lambda temporária que executa o SQL de criação da tabela.

---

## 🧪 Testar a API

### Obter a URL

```powershell
$apiUrl = terraform output -raw api_gateway_invoke_url
Write-Host "API URL: $apiUrl"
```

### Criar uma Task (POST)

```powershell
$body = @{
    title = "Minha primeira task"
    description = "Teste da API"
    status = "pending"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/tasks" -Method POST -Body $body -ContentType "application/json"
```

### Listar Tasks (GET)

```powershell
Invoke-RestMethod -Uri "$apiUrl/tasks" -Method GET
```

---

## 🔄 Atualizar Lambda

Se você alterar o código da Lambda:

1. **Atualize o código** em `lambda/criar_task/index.js`

2. **Recrie o ZIP:**
   ```powershell
   cd lambda/criar_task
   Compress-Archive -Path * -DestinationPath ..\..\build\criar_task.zip -Force
   cd ..\..
   ```

3. **Aplique novamente:**
   ```powershell
   cd infra
   terraform apply
   ```

O Terraform detectará a mudança no `source_code_hash` e atualizará a Lambda automaticamente.

---

## 🗑️ Destruir Tudo

**⚠️ CUIDADO: Isso apaga TODOS os recursos!**

```powershell
terraform destroy -auto-approve
```

**OU** (com confirmação):

```powershell
terraform destroy
```

**O que será destruído:**
- ✅ VPC, Subnets, Gateways
- ✅ Security Groups
- ✅ RDS MySQL (⚠️ dados serão perdidos!)
- ✅ S3 Buckets (⚠️ arquivos serão perdidos!)
- ✅ Lambda Functions
- ✅ API Gateway
- ✅ IAM Roles e Policies
- ✅ Secrets Manager secrets

**NÃO será destruído:**
- ❌ Bucket S3 do backend (terraform state)
- ❌ Tabela DynamoDB do backend (terraform locks)

---

## 📝 Comandos Úteis

### Verificar estado

```powershell
terraform show
```

### Validar configuração

```powershell
terraform validate
```

### Formatar código

```powershell
terraform fmt
```

### Ver recursos criados

```powershell
terraform state list
```

### Ver detalhes de um recurso

```powershell
terraform state show aws_db_instance.tasks_db
```

---

## 🆘 Troubleshooting

### Erro: Backend não encontrado
```
Error: error loading state: bucket "meu-terraform-state-bucket-uniqueno" not found
```
**Solução:** Verifique se o bucket S3 existe na região sa-east-1

### Erro: Credenciais não encontradas
```
Error: No valid credential sources found
```
**Solução:** Verifique `C:\Users\iagoc\.aws\credentials`

### Erro: Lambda ZIP não encontrado
```
Error: open build/criar_task.zip: no such file or directory
```
**Solução:** Certifique-se de que o ZIP existe em `build/criar_task.zip`

### Erro: RDS não pode ser criado
```
Error: creating RDS DB Instance: InvalidParameterValue
```
**Solução:** Verifique a senha no `terraform.tfvars` (deve ter pelo menos 8 caracteres)

---

**Última atualização:** 2024

