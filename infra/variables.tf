# ============================================================================
# Variáveis de Configuração Geral
# ============================================================================

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome do projeto (usado para nomenclatura de recursos)"
  type        = string
  default     = "nuvem"
}

# ============================================================================
# Variáveis de Rede
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidade para subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ============================================================================
# Variáveis de Instâncias (Classes)
# ============================================================================

variable "instance_type" {
  description = "Tipo/classe de instância EC2"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Classe da instância RDS (ex: db.t3.micro, db.t3.small)"
  type        = string
  default     = "db.t3.micro"
}

# ============================================================================
# Variáveis de RDS
# ============================================================================

variable "db_name" {
  description = "Nome do banco de dados MySQL"
  type        = string
  default     = "appdb"
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado para RDS (GB)"
  type        = number
  default     = 20
}

# ============================================================================
# Variáveis Sensíveis (Credenciais)
# ============================================================================

variable "db_username" {
  description = "Usuário do banco de dados RDS MySQL"
  type        = string
  sensitive   = true
  # IMPORTANTE: NUNCA coloque valores hardcoded aqui.
  # Use terraform.tfvars (não versionado) ou variáveis de ambiente (TF_VAR_db_username)
}

variable "db_password" {
  description = "Senha do banco de dados RDS MySQL"
  type        = string
  sensitive   = true
  # IMPORTANTE: NUNCA coloque valores hardcoded aqui.
  # Use terraform.tfvars (não versionado) ou variáveis de ambiente (TF_VAR_db_password)
  # As aplicações devem usar AWS Secrets Manager para obter as credenciais em runtime.
}

