# ============================================================================
# rds.tf - Banco de Dados RDS MySQL e Secrets Manager
# ============================================================================
# Este arquivo cria:
# 1. DB Subnet Group: Define em quais subnets o RDS pode ser criado
# 2. Secrets Manager: Armazena credenciais do banco de forma segura
# 3. RDS Instance: Instância MySQL do banco de dados
#
# Segurança:
# - RDS em subnets privadas (sem acesso direto da internet)
# - Credenciais no Secrets Manager (não hardcoded)
# - Security group muito restritivo (apenas de Lambdas/ECS)
# ============================================================================

# DB Subnet Group
# Define quais subnets o RDS pode usar (deve ser pelo menos 2 em AZs diferentes)
# RDS precisa estar em subnets privadas para segurança
resource "aws_db_subnet_group" "tasks" {
  name       = "tasks-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id  # Todas as subnets privadas

  tags = {
    Name = "tasks-db-subnet-group"
  }
}

# AWS Secrets Manager - Secret para credenciais do RDS
# Armazena username e password do banco de forma segura e criptografada
# As aplicações (Lambda/ECS) leem este secret em runtime
# 
# IMPORTANTE: Se você receber erro de que o secret já existe e está agendado para deleção,
# você precisa restaurar ou remover o secret manualmente antes:
# - Via AWS Console: Restaurar o secret cancelando a deleção
# - Via AWS CLI: aws secretsmanager restore-secret --secret-id nuvem-rds-credentials --region sa-east-1
# - Ou remover: aws secretsmanager delete-secret --secret-id nuvem-rds-credentials --force-delete-without-recovery --region sa-east-1
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${var.project_name}-rds-credentials"
  description = "Credenciais do banco de dados RDS MySQL"

  tags = {
    Name = "${var.project_name}-rds-credentials"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Versão do secret com username e password
# IMPORTANTE: Este secret armazena as credenciais do RDS de forma segura.
# As Lambdas/ECS devem usar este secret para obter as credenciais, NÃO usar variáveis hardcoded.
# Nota: host e port serão atualizados após criação do RDS ou podem ser obtidos via outputs
resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username # Variável sensível
    password = var.db_password # Variável sensível - NUNCA hardcode
    engine   = "mysql"
    dbname   = var.db_name
    # host e port serão preenchidos após criação do RDS
    # ou podem ser obtidos via variáveis de ambiente/outputs
  })
}

# RDS Instance
# IMPORTANTE: As credenciais (username/password) são necessárias apenas para criação inicial do RDS.
# Após a criação, as aplicações (Lambdas/ECS) devem usar AWS Secrets Manager para obter as credenciais.
# NUNCA coloque senhas hardcoded no código. Use terraform.tfvars ou variáveis de ambiente.
resource "aws_db_instance" "tasks_db" {
  identifier         = "tasks-db"
  engine             = "mysql"
  engine_version     = "8.0"
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  storage_type       = "gp3"
  db_name            = var.db_name
  username           = var.db_username
  password           = var.db_password # Variável sensível - fornecer via terraform.tfvars ou TF_VAR_db_password
  db_subnet_group_name = aws_db_subnet_group.tasks.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Multi-AZ para produção, Single-AZ para dev
  multi_az = var.environment == "prod"

  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  skip_final_snapshot = var.environment != "prod"
  deletion_protection  = var.environment == "prod"

  # Para MySQL, os valores válidos são apenas "error" e "general"
  # "slow_query" é válido apenas para MariaDB, não para MySQL
  enabled_cloudwatch_logs_exports = ["error", "general"]

  tags = {
    Name = "tasks-db"
  }
}

# RDS Parameter Group (opcional - para customizações)
# resource "aws_db_parameter_group" "main" {
#   name   = "${var.project_name}-db-params"
#   family = "mysql8.0"
#
#   parameter {
#     name  = "max_connections"
#     value = "100"
#   }
#
#   tags = {
#     Name = "${var.project_name}-db-params"
#   }
# }

# ============================================================================
# Criar tabela automaticamente após RDS estar disponível
# ============================================================================
# Este recurso executa o script PowerShell init-database.ps1 automaticamente
# após o RDS estar disponível (status = available)
#
# IMPORTANTE: 
# - Requer Node.js/npm instalado (para criar ZIP da Lambda)
# - O script cria uma Lambda temporária que executa o SQL e depois a deleta
# - Se o script falhar, você pode executá-lo manualmente: .\init-database.ps1
# ============================================================================
resource "null_resource" "create_table" {
  depends_on = [
    aws_db_instance.tasks_db,
    aws_secretsmanager_secret_version.rds_credentials
  ]

  triggers = {
    # Executa sempre que o endpoint do RDS mudar (nova criação)
    rds_endpoint = aws_db_instance.tasks_db.endpoint
    
    # Executa se o SQL mudar (você pode forçar executar alterando este arquivo)
    sql_hash = filemd5("${path.module}/../lambda/criar_task/create_table.sql")
  }

  # Executar script PowerShell para criar tabela
  # ⚠️ IMPORTANTE: on_failure = continue permite que o Terraform continue mesmo se o script falhar
  # O script pode falhar se os outputs ainda não estiverem disponíveis durante o primeiro apply
  # Neste caso, execute o script manualmente após o terraform apply: .\init-database.ps1
  provisioner "local-exec" {
    command     = "powershell.exe -ExecutionPolicy Bypass -File ${path.module}/init-database.ps1 -AWS_REGION ${var.aws_region}"
    interpreter = ["PowerShell", "-Command"]
    on_failure  = continue  # Continuar mesmo se o script falhar (outputs podem não estar disponíveis ainda)
  }

  # Se o script falhar, não falhar o terraform (apenas aviso)
  provisioner "local-exec" {
    when        = destroy
    command     = "Write-Host 'Limpeza: Se houver Lambda temporária, ela será deletada no próximo run do script'"
    interpreter = ["PowerShell", "-Command"]
    on_failure  = continue
  }
}
