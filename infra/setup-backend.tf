# ============================================================================
# setup-backend.tf - Criação do Backend (S3 + DynamoDB)
# ============================================================================
# Este arquivo cria os recursos necessários para o backend do Terraform:
# - Bucket S3 para armazenar o state file
# - Tabela DynamoDB para locking
#
# INSTRUÇÕES:
# 1. Execute este arquivo PRIMEIRO (antes do terraform init do projeto principal)
# 2. terraform init (sem backend)
# 3. terraform plan
# 4. terraform apply
# 5. Depois disso, você pode usar o backend normalmente
#
# NOTA: Este arquivo usa as configurações de terraform e provider definidas
# em providers.tf. Não define suas próprias configurações para evitar duplicação.
# ============================================================================

# Bucket S3 para armazenar o state do Terraform
# NOTA: Este bucket já foi criado manualmente em us-east-1 e não deve ser gerenciado aqui.
# O bucket é usado apenas como backend do Terraform e não precisa estar no estado do Terraform.
# Removido para evitar conflitos - o bucket já existe e funciona corretamente.

# Tabela DynamoDB para locking do Terraform
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"  # On-demand (sem provisionar capacidade)
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Locking"
    Purpose   = "Terraform Backend Locking"
    ManagedBy = "Terraform"
  }
}

# Outputs
output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

