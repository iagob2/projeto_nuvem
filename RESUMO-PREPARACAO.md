# ✅ Resumo da Preparação - Tudo Pronto!

## 🎉 O que já foi feito:

### ✅ 1. Estrutura da Lambda
- **Diretório:** `lambda/criar_task/`
- **Código:** `lambda/criar_task/index.js` (com suporte a GET e POST)
- **Dependências:** `package.json` com aws-sdk e mysql2
- **Pacotes instalados:** ✅ npm install concluído

### ✅ 2. ZIP da Lambda
- **Arquivo:** `build/criar_task.zip` (14.8 MB)
- **Conteúdo:** index.js + node_modules
- **Status:** ✅ Pronto para deploy

### ✅ 3. Configuração Terraform
- **Backend:** Configurado para S3 + DynamoDB (já criados manualmente)
- **Variáveis:** `terraform.tfvars` corrigido (senha com aspas)
- **Arquivos:** Todos os `.tf` criados e comentados

### ✅ 4. Script SQL
- **Arquivo:** `lambda/criar_task/create_table.sql`
- **Função:** Cria a tabela `tasks` no banco

### ✅ 5. Documentação
- **DEPLOY.md:** Guia completo de deploy
- **COMANDOS-TERRAFORM.md:** Comandos passo a passo
- **README.md:** Documentação da arquitetura

---

## ⚠️ O que você precisa fazer:

### 1. Instalar Terraform

**Opção A: Download Manual**
1. Acesse: https://www.terraform.io/downloads
2. Baixe a versão Windows (64-bit)
3. Extraia o ZIP
4. Adicione o diretório ao PATH do Windows

**Opção B: Via Chocolatey (se tiver)**
```powershell
choco install terraform
```

**Opção C: Via Scoop (se tiver)**
```powershell
scoop install terraform
```

**Verificar instalação:**
```powershell
terraform version
```

---

### 2. Executar os Comandos Terraform

**Navegar para o diretório:**
```powershell
cd infra
```

**Inicializar:**
```powershell
terraform init
```

**Verificar plano:**
```powershell
terraform plan -out=tfplan
```

**Aplicar:**
```powershell
terraform apply tfplan
```

**Ver outputs:**
```powershell
terraform output
```

---

### 3. Criar a Tabela no Banco

Após o RDS ser criado, execute o SQL:

**Via AWS Console (RDS Query Editor):**
1. Acesse: https://console.aws.amazon.com/rds/
2. Selecione sua instância RDS
3. Clique em "Query Editor"
4. Cole o conteúdo de `lambda/criar_task/create_table.sql`
5. Execute

---

### 4. Testar a API

**Obter URL:**
```powershell
cd infra
$apiUrl = terraform output -raw api_gateway_invoke_url
```

**Criar task:**
```powershell
$body = @{
    title = "Minha primeira task"
    description = "Teste"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/tasks" -Method POST -Body $body -ContentType "application/json"
```

**Listar tasks:**
```powershell
Invoke-RestMethod -Uri "$apiUrl/tasks" -Method GET
```

---

## 📁 Estrutura Final do Projeto

```
projeto_testes/
├── infra/                          # Configuração Terraform
│   ├── *.tf                        # Arquivos de configuração
│   ├── terraform.tfvars            # Variáveis (senhas)
│   └── ...
├── lambda/                         # Código das Lambdas
│   └── criar_task/
│       ├── index.js                # Código principal
│       ├── package.json            # Dependências
│       └── create_table.sql        # SQL para criar tabela
├── build/                          # Artefatos de build
│   └── criar_task.zip              # ZIP da Lambda (14.8 MB)
├── DEPLOY.md                       # Guia de deploy
├── COMANDOS-TERRAFORM.md           # Comandos Terraform
└── RESUMO-PREPARACAO.md           # Este arquivo
```

---

## 🔍 Checklist Final

Antes de executar `terraform apply`:

- [ ] Terraform instalado (`terraform version`)
- [ ] Credenciais AWS configuradas (`C:\Users\iagoc\.aws\credentials`)
- [ ] Backend S3 criado (bucket: `meu-terraform-state-bucket-uniqueno`)
- [ ] Backend DynamoDB criado (tabela: `terraform-locks`)
- [ ] ZIP da Lambda existe (`build/criar_task.zip`)
- [ ] Senha do banco corrigida em `terraform.tfvars`
- [ ] Região correta (sa-east-1) em `terraform.tfvars`

---

## 📚 Documentação de Referência

- **Arquitetura:** `infra/README.md`
- **Segurança:** `infra/SECURITY.md`
- **Backend Setup:** `infra/SETUP-BACKEND.md`
- **Deploy:** `DEPLOY.md`
- **Comandos:** `COMANDOS-TERRAFORM.md`

---

## 🆘 Problemas Comuns

### Terraform não encontrado
**Solução:** Instale o Terraform e adicione ao PATH

### Backend não encontrado
**Solução:** Verifique se o bucket S3 e DynamoDB existem em sa-east-1

### Lambda ZIP não encontrado
**Solução:** O ZIP já está criado em `build/criar_task.zip`

### Senha do banco inválida
**Solução:** Verifique `infra/terraform.tfvars` - a senha deve ter pelo menos 8 caracteres

---

**Tudo está pronto! Agora é só instalar o Terraform e executar os comandos! 🚀**

