# ============================================================================
# s3.tf - Buckets S3 para Armazenamento
# ============================================================================
# Este arquivo cria buckets S3 para armazenar arquivos:
# 1. app_storage: Armazenamento geral da aplicação
# 2. csv_bucket: Específico para arquivos CSV (usado pelas Lambdas)
# 3. logs: Para logs (opcional)
#
# Segurança:
# - Block Public Access habilitado
# - Encriptação server-side (AES256)
# - Versionamento para recuperação de arquivos
# ============================================================================

# S3 Bucket para armazenamento geral de arquivos
# Pode ser usado para armazenar qualquer tipo de arquivo da aplicação
resource "aws_s3_bucket" "app_storage" {
  bucket = "${var.project_name}-storage-${var.environment}"

  tags = {
    Name = "${var.project_name}-storage"
  }
}

# Versionamento do bucket
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptação do bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy (opcional)
resource "aws_s3_bucket_lifecycle_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    
    # Filter vazio significa aplicar a todos os objetos do bucket
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    
    # Filter vazio significa aplicar a todos os objetos do bucket
    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# S3 Bucket para logs (opcional)
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs-${var.environment}"

  tags = {
    Name = "${var.project_name}-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket para CSVs
# Bucket específico para armazenar arquivos CSV gerados pelas Lambdas
# Nome único globalmente (deve ser único em toda a AWS)
resource "aws_s3_bucket" "csv_bucket" {
  bucket = "meu-bucket-tasks-csv-unico"  # Nome único globalmente (apenas minúsculas)

  tags = {
    Name = "tasks-csv-bucket"
  }
}

# ACL do bucket CSV
# NOTA: Removido - novos buckets S3 da AWS não suportam ACLs por padrão.
# O bucket já é privado por padrão quando o Block Public Access está habilitado.
# Se você precisar de controle de acesso, use bucket policies.

# Versionamento do bucket CSV
resource "aws_s3_bucket_versioning" "csv_bucket" {
  bucket = aws_s3_bucket.csv_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptação do bucket CSV
resource "aws_s3_bucket_server_side_encryption_configuration" "csv_bucket" {
  bucket = aws_s3_bucket.csv_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access do bucket CSV
resource "aws_s3_bucket_public_access_block" "csv_bucket" {
  bucket = aws_s3_bucket.csv_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

