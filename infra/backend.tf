# ============================================================================
# backend.tf - Configuração do Backend Remoto do Terraform
# ============================================================================
# Este arquivo configura onde o Terraform armazena o estado (state file).
# O estado contém informações sobre os recursos criados e suas dependências.
#
# Backend S3 + DynamoDB:
# - S3: Armazena o arquivo de estado (terraform.tfstate)
# - DynamoDB: Fornece locking para evitar conflitos em execuções simultâneas
# - encrypt: true garante que o estado seja criptografado no S3
#
# IMPORTANTE: 
# - O bucket S3 e a tabela DynamoDB devem existir antes de executar terraform init
# - Configure as credenciais AWS antes de usar este backend
# ============================================================================

terraform {
  backend "s3" {
    bucket         = "meu-terraform-state-bucket-uniqueno"  # Bucket para armazenar o state
    key            = "tasks-architecture/terraform.tfstate"  # Caminho do arquivo de estado
    region         = "us-east-1"                            # Região do bucket (ajustada para corresponder à localização real)
    dynamodb_table = "terraform-locks"                       # Tabela DynamoDB para locking
    encrypt        = true                                    # Criptografar o estado
    # Nota: dynamodb_table ainda é necessário para locking. O aviso sobre "use_lockfile" 
    # é apenas informativo - o parâmetro dynamodb_table continua funcionando corretamente.
  }
}
