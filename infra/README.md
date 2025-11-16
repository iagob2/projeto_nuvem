# Documentação da Infraestrutura - Projeto Nuvem

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Estrutura de Arquivos](#estrutura-de-arquivos)
4. [Fluxo de Funcionamento](#fluxo-de-funcionamento)
5. [Como Usar](#como-usar)
6. [Segurança](#segurança)

---

## 🎯 Visão Geral

Este projeto define uma infraestrutura completa na AWS usando Terraform, incluindo:

- **VPC** com subnets públicas e privadas
- **RDS MySQL** para banco de dados
- **Lambda Functions** para processamento serverless
- **API Gateway** para expor APIs REST
- **S3 Buckets** para armazenamento de arquivos
- **Security Groups** com regras restritivas
- **IAM Roles e Policies** seguindo o princípio de menor privilégio

---

## 🏗️ Arquitetura

```
Internet
   │
   ├── API Gateway (REST API)
   │       │
   │       └── Lambda Functions (VPC)
   │               │
   │               ├── RDS MySQL (Subnets Privadas)
   │               └── S3 Bucket (CSVs)
   │
   ├── ALB (Application Load Balancer) # (Balanceador de Carga de Aplicativos)
   │       │
   │       └── EC2 Frontend (Subnets Públicas)
   │
   └── ECS Cluster (Opcional)
           └── ECS Tasks (Subnets Privadas)
                   │
                   ├── RDS MySQL
                   └── S3 Bucket
```

### Componentes Principais:

1. **VPC** (`10.0.0.0/16`)
   - 2 Subnets Públicas (front-end/ALB)
   - 2 Subnets Privadas (Lambdas, RDS)
   - Internet Gateway
   - NAT Gateway

2. **RDS MySQL**
   - Instância em subnets privadas
   - Credenciais no AWS Secrets Manager
   - Multi-AZ em produção

3. **Lambda Functions**
   - Executam em VPC (subnets privadas)
   - Acessam RDS via Secrets Manager
   - Escrevem CSVs no S3

4. **API Gateway**
   - Proxy integration para Lambda
   - CORS configurado

---

## 📁 Estrutura de Arquivos

### Arquivos de Configuração Base

#### `backend.tf`
**O que faz:** Configura onde o Terraform armazena o estado (state file).

**Como funciona:**
- Define backend remoto no S3 para armazenar o estado
- Usa DynamoDB para locking (evita conflitos)
- Estado é criptografado no S3

**Dependências:** Bucket S3 e tabela DynamoDB devem existir antes de `terraform init`.

---

#### `providers.tf`
**O que faz:** Configura o provider AWS e versões do Terraform.

**Como funciona:**
- Define versão mínima do Terraform (>= 1.0)
- Configura provider AWS (versão ~> 5.0)
- Define tags padrão para todos os recursos

**Tags aplicadas:** Environment, Project, ManagedBy

---

#### `variables.tf`
**O que faz:** Define todas as variáveis usadas no projeto.

**Variáveis principais:**
- `aws_region`: Região AWS (ex: sa-east-1)
- `environment`: Ambiente (dev/staging/prod)
- `project_name`: Nome do projeto (nuvem)
- `instance_type`: Tipo de instância EC2
- `db_instance_class`: Classe da instância RDS
- `db_username`, `db_password`: Credenciais sensíveis

**Como usar:** Forneça valores via `terraform.tfvars` ou variáveis de ambiente.

---

#### `outputs.tf`
**O que faz:** Expõe valores importantes após a criação da infraestrutura.

**Outputs principais:**
- `rds_endpoint`: Endpoint do RDS (host:port)
- `s3_bucket_name`: Nome do bucket S3 para CSVs
- `api_gateway_invoke_url`: URL do API Gateway

**Como usar:** Execute `terraform output` para ver os valores.

---

#### `main.tf`
**O que faz:** Arquivo principal de orquestração (atualmente vazio, pode ser usado para módulos).

**Uso futuro:** Pode ser usado para chamar módulos reutilizáveis.

---

### Arquivos de Recursos de Rede

#### `networking.tf`
**O que faz:** Cria toda a infraestrutura de rede (VPC, subnets, gateways, route tables).

**Recursos criados:**
1. **VPC** (`aws_vpc.main`)
   - CIDR: `10.0.0.0/16`
   - DNS habilitado

2. **Internet Gateway** (`aws_internet_gateway.main`)
   - Permite acesso à internet para subnets públicas

3. **Subnets Públicas** (`aws_subnet.public`)
   - 2 subnets (uma por AZ)
   - `map_public_ip_on_launch = true`
   - Para: ALB, EC2 frontend

4. **Subnets Privadas** (`aws_subnet.private`)
   - 2 subnets (uma por AZ)
   - Para: RDS, Lambdas em VPC, ECS

5. **NAT Gateway** (`aws_nat_gateway.main`)
   - Permite subnets privadas acessarem internet
   - Elastic IP associado

6. **Route Tables**
   - Pública: rota para Internet Gateway
   - Privada: rota para NAT Gateway

**Fluxo:**
```
Internet → IGW → Subnet Pública → ALB/EC2
Subnet Privada → NAT Gateway → IGW → Internet
```

---

### Arquivos de Segurança

#### `security_groups.tf`
**O que faz:** Define regras de firewall (security groups) para todos os recursos.

**Security Groups criados:**

1. **alb-sg** (ALB)
   - Ingress: HTTP (80), HTTPS (443) de `0.0.0.0/0`
   - Egress: Tudo

2. **frontend-sg** (EC2 Frontend)
   - Ingress: HTTP/HTTPS de `0.0.0.0/0` e do ALB
   - Ingress: SSH (22) - restringir em produção
   - Egress: Tudo

3. **ecs-sg** (ECS Tasks)
   - Ingress: HTTP/HTTPS apenas do ALB
   - Egress: RDS (3306), S3 (443), DNS (53)

4. **rds-sg** (RDS) ⚠️ **MUITO RESTRITIVO**
   - Ingress: MySQL (3306) **APENAS** de `ecs-sg` e `lambda-sg`
   - **NÃO** tem acesso da internet
   - Sem egress

5. **lambda-sg** (Lambda em VPC)
   - Sem ingress (Lambda não recebe conexões)
   - Egress: RDS (3306), S3 (443), DNS (53)

**Princípio:** Menor privilégio - apenas o necessário.

---

### Arquivos de Computação

#### `ec2_front.tf`
**O que faz:** Cria instâncias EC2 para frontend.

**Recursos:**
- Data source para AMI mais recente do Amazon Linux
- Instância EC2 em subnet pública
- Elastic IP associado

**Uso:** Pode ser usado para hospedar aplicação frontend ou bastion host.

---

#### `ecs.tf`
**O que faz:** Cria cluster ECS (opcional, recursos comentados).

**Recursos:**
- ECS Cluster
- CloudWatch Log Group para logs do ECS
- Exemplos comentados de Task Definition e Service

**Uso:** Descomente e configure se precisar usar ECS em vez de Lambda.

---

#### `lambda.tf`
**O que faz:** Cria funções Lambda e configura IAM.

**Recursos criados:**

1. **IAM Role** (`aws_iam_role.lambda`)
   - Assume role policy para Lambda

2. **IAM Policy** (`aws_iam_policy.lambda_policy`)
   - CloudWatch Logs (CreateLogGroup, CreateLogStream, PutLogEvents)
   - S3 (PutObject, GetObject, DeleteObject, ListBucket) - apenas bucket CSV
   - Secrets Manager (GetSecretValue, DescribeSecret) - apenas leitura

3. **Lambda Function** (`aws_lambda_function.criar_task`)
   - Runtime: Node.js 18.x
   - Handler: `index.handler`
   - VPC config: subnets privadas + security group
   - Variáveis de ambiente: DB_SECRET_ARN, RDS_ENDPOINT, etc.

**Fluxo:**
```
API Gateway → Lambda → Secrets Manager (credenciais) → RDS
                      → S3 (escrever CSV)
```

---

### Arquivos de Banco de Dados

#### `rds.tf`
**O que faz:** Cria banco de dados RDS MySQL e configura Secrets Manager.

**Recursos criados:**

1. **DB Subnet Group** (`aws_db_subnet_group.tasks`)
   - Aponta para subnets privadas
   - Necessário para RDS em VPC

2. **Secrets Manager Secret** (`aws_secretsmanager_secret.rds_credentials`)
   - Armazena credenciais do RDS de forma segura

3. **Secret Version** (`aws_secretsmanager_secret_version.rds_credentials`)
   - Contém: username, password, engine, dbname

4. **RDS Instance** (`aws_db_instance.tasks_db`)
   - Engine: MySQL 8.0
   - Multi-AZ em produção, Single-AZ em dev
   - Backup configurado
   - CloudWatch logs habilitados

**Segurança:**
- RDS em subnets privadas (sem acesso direto da internet)
- Credenciais no Secrets Manager (não hardcoded)
- Security group muito restritivo

---

### Arquivos de Armazenamento

#### `s3.tf`
**O que faz:** Cria buckets S3 para armazenamento.

**Buckets criados:**

1. **app_storage** (`aws_s3_bucket.app_storage`)
   - Armazenamento geral
   - Versionamento habilitado
   - Encriptação AES256
   - Lifecycle policies (transição para IA/Glacier)

2. **csv_bucket** (`aws_s3_bucket.csv_bucket`)
   - Específico para arquivos CSV
   - Nome: `meu-bucket-tasks-csv-UNICO`
   - Versionamento habilitado
   - Encriptação AES256
   - ACL: private

3. **logs** (`aws_s3_bucket.logs`)
   - Para logs (opcional)

**Segurança:**
- Block Public Access habilitado
- Encriptação server-side
- Versionamento para recuperação

---

### Arquivos de API

#### `api_gateway.tf`
**O que faz:** Cria API Gateway REST API com integração Lambda.

**Recursos criados:**

1. **REST API** (`aws_api_gateway_rest_api.tasks_api`)
   - Tipo: REGIONAL

2. **Resource Proxy** (`aws_api_gateway_resource.proxy`)
   - Path: `{proxy+}` (captura todas as rotas)

3. **Method** (`aws_api_gateway_method.proxy`)
   - HTTP Method: ANY (GET, POST, PUT, DELETE)
   - Authorization: NONE (pode adicionar depois)

4. **Integration** (`aws_api_gateway_integration.lambda_proxy`)
   - Tipo: AWS_PROXY
   - Integra com Lambda

5. **Lambda Permission** (`aws_lambda_permission.apigw_invoke_criar_task`)
   - Permite API Gateway invocar Lambda

6. **Deployment e Stage**
   - Deployment: versão da API
   - Stage: ambiente (dev/staging/prod)

**Fluxo:**
```
Cliente → API Gateway → Lambda → RDS/S3
```

---

### Arquivos de IAM

#### `iam.tf`
**O que faz:** Cria roles e policies IAM para ECS e EC2.

**Roles criadas:**

1. **ecs_execution** (ECS Task Execution Role)
   - Permite ECS puxar imagens, escrever logs
   - Usa managed policy `AmazonECSTaskExecutionRolePolicy`

2. **ecs_task** (ECS Task Role)
   - Permite tarefas acessarem S3 e Secrets Manager
   - Policies inline para S3 e Secrets Manager

3. **ec2** (EC2 Instance Role)
   - Para EC2 acessar outros serviços AWS
   - Instance profile associado

**Princípio:** Menor privilégio - apenas permissões necessárias.

---

## 🔄 Fluxo de Funcionamento

### 1. Criação da Infraestrutura

```bash
terraform init    # Inicializa backend, baixa providers
terraform plan    # Mostra o que será criado
terraform apply   # Cria os recursos
```

**Ordem de criação:**
1. VPC e networking
2. Security groups
3. IAM roles e policies
4. S3 buckets
5. Secrets Manager (secret vazio)
6. RDS (usa credenciais das variáveis)
7. Secrets Manager (atualiza com credenciais)
8. Lambda functions
9. API Gateway

### 2. Fluxo de Requisição API

```
1. Cliente faz requisição HTTP → API Gateway
2. API Gateway → Lambda (via proxy integration)
3. Lambda:
   a. Lê credenciais do Secrets Manager
   b. Conecta ao RDS MySQL
   c. Processa requisição
   d. Escreve CSV no S3 (se necessário)
4. Lambda retorna resposta → API Gateway → Cliente
```

### 3. Acesso ao RDS

```
Lambda/ECS → Security Group (lambda-sg/ecs-sg)
          → Security Group (rds-sg) - permite apenas de lambda-sg/ecs-sg
          → RDS MySQL (subnet privada)
```

**Segurança:** RDS não é acessível diretamente da internet.

---

## 🚀 Como Usar

### Pré-requisitos

1. AWS CLI configurado (ou credenciais em `~/.aws/credentials`)
2. Terraform >= 1.0 instalado
3. **Bucket S3 e tabela DynamoDB para backend** ⚠️ **CRIAR ANTES!**

   **IMPORTANTE:** Você precisa criar o bucket S3 e a tabela DynamoDB antes de executar `terraform init`.
   
   Veja o arquivo `SETUP-BACKEND.md` para instruções detalhadas de como criar esses recursos.

### Passo a Passo

1. **Clone o repositório**
   ```bash
   cd infra
   ```

2. **Configure variáveis**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edite terraform.tfvars com seus valores
   ```

3. **Inicialize Terraform**
   ```bash
   terraform init
   ```

4. **Planeje mudanças**
   ```bash
   terraform plan
   ```

5. **Aplique mudanças**
   ```bash
   terraform apply
   ```

6. **Veja outputs**
   ```bash
   terraform output
   ```

### Variáveis Importantes

Edite `terraform.tfvars`:
```hcl
aws_region     = "sa-east-1"
environment    = "dev"
project_name   = "nuvem"
db_username    = "admin"
db_password    = "sua_senha_segura"
```

---

## 🔒 Segurança

### Credenciais

- ✅ Variáveis sensíveis marcadas como `sensitive = true`
- ✅ Credenciais no AWS Secrets Manager (não hardcoded)
- ✅ `terraform.tfvars` no `.gitignore`

### IAM

- ✅ Princípio de menor privilégio
- ✅ Permissões restritas por recurso
- ✅ Apenas leitura no Secrets Manager

### Rede

- ✅ RDS em subnets privadas
- ✅ Security groups muito restritivos
- ✅ NAT Gateway para acesso controlado à internet

### Documentação Adicional

Veja `SECURITY.md` para mais detalhes sobre segurança.

---

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

## 🆘 Troubleshooting

### Erro: Backend não encontrado
**Solução:** Crie o bucket S3 e tabela DynamoDB antes de `terraform init`.

### Erro: Credenciais não fornecidas
**Solução:** Configure `terraform.tfvars` ou variáveis de ambiente.

### Erro: Lambda não consegue acessar RDS
**Solução:** Verifique security groups e se Lambda está em VPC.

---


