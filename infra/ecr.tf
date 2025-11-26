# ============================================================================
# ecr.tf - Elastic Container Registry (ECR)
# ============================================================================
# Este arquivo cria repositórios ECR para armazenar as imagens Docker
# dos containers do back-end e front-end.
# ============================================================================

# Repositório ECR para Back-end
# ⚠️ IMPORTANTE: Se o repositório já existir, importe-o com:
# terraform import aws_ecr_repository.backend back-end-nuvem
resource "aws_ecr_repository" "backend" {
  name                 = "back-end-nuvem"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "back-end-nuvem"
  }

  # Se o repositório já existir, o Terraform tentará criá-lo e falhará
  # Use terraform import para importar o recurso existente
  lifecycle {
    create_before_destroy = true
  }
}

# Repositório ECR para Front-end
# ⚠️ IMPORTANTE: Se o repositório já existir, importe-o com:
# terraform import aws_ecr_repository.frontend frontend-nuvem
resource "aws_ecr_repository" "frontend" {
  name                 = "frontend-nuvem"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "frontend-nuvem"
  }

  # Se o repositório já existir, o Terraform tentará criá-lo e falhará
  # Use terraform import para importar o recurso existente
  lifecycle {
    create_before_destroy = true
  }
}

# Lifecycle policy para ECR Back-end (manter apenas últimas 5 imagens)
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as últimas 5 imagens"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy para ECR Front-end (manter apenas últimas 5 imagens)
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as últimas 5 imagens"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

