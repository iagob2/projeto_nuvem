# ============================================================================
# providers.tf - Configuração de Providers e Versões do Terraform
# ============================================================================
# Este arquivo define:
# 1. Versão mínima do Terraform necessária
# 2. Providers necessários (AWS) e suas versões
# 3. Configuração do provider AWS (região, tags padrão)
#
# Tags padrão são aplicadas automaticamente a todos os recursos criados,
# facilitando organização e gerenciamento de custos.
# ============================================================================

# Configuração de versões do Terraform
terraform {
  required_version = ">= 1.0"  # Versão mínima do Terraform

  # Providers necessários
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Provider oficial da AWS
      version = "~> 5.0"         # Versão 5.x (5.0 até 5.99)
    }
  }
}

# Configuração do Provider AWS
provider "aws" {
  region = var.aws_region  # Região onde os recursos serão criados
  # O caminho de credenciais
  # shared_credentials_file não precisa ser especificado - o SDK já procura automaticamente em:
  # - Windows: %USERPROFILE%\.aws\credentials
  # - Linux/Mac: ~/.aws/credentials
  # Ou use variáveis de ambiente: AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY

  # Tags padrão aplicadas a todos os recursos
  default_tags {
    tags = {
      Environment = var.environment  # dev, staging, prod
      Project     = var.project_name # Nome do projeto (nuvem)
      ManagedBy   = "Terraform"      # Indica que é gerenciado por Terraform
    }
  }
}

