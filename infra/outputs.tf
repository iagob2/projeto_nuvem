# ============================================================================
# Outputs Principais (Solicitados)
# ============================================================================

output "rds_endpoint" {
  description = "Endpoint do RDS MySQL (host:port)"
  value       = aws_db_instance.tasks_db.endpoint
}

output "s3_bucket_name" {
  description = "Nome do bucket S3 para CSVs"
  value       = aws_s3_bucket.csv_bucket.id
}

output "api_gateway_invoke_url" {
  description = "URL de invocação do API Gateway"
  value       = aws_api_gateway_stage.tasks_api.invoke_url
}

# ============================================================================
# Outputs Adicionais
# ============================================================================

# VPC Outputs
output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

# EC2 Outputs
output "ec2_frontend_instance_id" {
  description = "ID da instância EC2 frontend"
  value       = aws_instance.frontend.id
}

output "ec2_frontend_public_ip" {
  description = "IP público da instância EC2 frontend"
  value       = aws_eip.frontend.public_ip
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID do cluster ECS"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN do cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

# RDS Outputs (adicionais)
output "rds_address" {
  description = "Endereço do RDS (apenas host)"
  value       = aws_db_instance.tasks_db.address
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.tasks_db.port
}

# Secrets Manager Outputs
output "rds_secret_arn" {
  description = "ARN do secret no Secrets Manager com credenciais do RDS"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_secret_name" {
  description = "Nome do secret no Secrets Manager"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

# S3 Outputs (adicionais)
output "s3_csv_bucket_id" {
  description = "ID do bucket S3 para CSVs"
  value       = aws_s3_bucket.csv_bucket.id
}

output "s3_csv_bucket_arn" {
  description = "ARN do bucket S3 para CSVs"
  value       = aws_s3_bucket.csv_bucket.arn
}

output "s3_bucket_id" {
  description = "ID do bucket S3 de armazenamento geral"
  value       = aws_s3_bucket.app_storage.id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 de armazenamento geral"
  value       = aws_s3_bucket.app_storage.arn
}

# Security Groups Outputs
output "alb_security_group_id" {
  description = "ID do security group do ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID do security group do ECS"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID do security group do RDS"
  value       = aws_security_group.rds.id
}

# Lambda Outputs
output "lambda_criar_task_arn" {
  description = "ARN da função Lambda CriarTask"
  value       = aws_lambda_function.criar_task.arn
}

output "lambda_criar_task_function_name" {
  description = "Nome da função Lambda CriarTask"
  value       = aws_lambda_function.criar_task.function_name
}

output "lambda_role_arn" {
  description = "ARN da IAM Role usada pelas Lambdas"
  value       = aws_iam_role.lambda.arn
}

output "lambda_security_group_id" {
  description = "ID do security group usado pelas Lambdas"
  value       = aws_security_group.lambda.id
}

# API Gateway Outputs (adicionais)
output "api_gateway_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.tasks_api.id
}

output "api_gateway_execution_arn" {
  description = "ARN de execução do API Gateway"
  value       = aws_api_gateway_rest_api.tasks_api.execution_arn
}

# ECR Outputs
output "ecr_backend_repository_url" {
  description = "URL do repositório ECR do back-end"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "URL do repositório ECR do front-end"
  value       = aws_ecr_repository.frontend.repository_url
}

# ECS Service Outputs
output "backend_service_name" {
  description = "Nome do serviço ECS do back-end"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Nome do serviço ECS do front-end"
  value       = aws_ecs_service.frontend.name
}

