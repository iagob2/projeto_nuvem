# Security Group para ALB/Frontend
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group para Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group para EC2 Frontend (frontend-sg)
resource "aws_security_group" "frontend" {
  name        = "frontend-sg"
  description = "Security group para instancias EC2 frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # Para restringir a IPs da sua organização, use:
    # cidr_blocks = ["IP_DA_ORG/32"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # Para restringir a IPs da sua organização, use:
    # cidr_blocks = ["IP_DA_ORG/32"]
  }

  ingress {
    description     = "HTTP do ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS do ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrinja conforme necessário
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# Security Group para ECS (ecs-sg)
resource "aws_security_group" "ecs" {
  name        = "ecs-sg"
  description = "Security group para tarefas ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP do ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS do ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress para acessar RDS (MySQL/Aurora)
  # Nota: Usamos CIDR das subnets privadas em vez de security_groups para evitar ciclo de dependências
  # A segurança é garantida pelo ingress do RDS que permite apenas dos security groups específicos
  egress {
    description = "MySQL/Aurora para RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }

  # Egress para acessar S3 (HTTPS)
  egress {
    description = "HTTPS para S3"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress para resolver DNS
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress geral (pode ser restringido conforme necessário)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}

# Security Group para RDS (rds-sg)
# IMPORTANTE: NÃO abrir RDS para a internet. Use regras restritas.
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group para RDS - acesso restrito apenas de ECS e Lambda"
  vpc_id      = aws_vpc.main.id

  # Permite acesso MySQL/Aurora apenas do ECS
  ingress {
    description     = "MySQL/Aurora do ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Permite acesso MySQL/Aurora apenas do Lambda
  ingress {
    description     = "MySQL/Aurora do Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Alternativa: Permitir apenas das subnets privadas (mais restritivo)
  # ingress {
  #   description = "MySQL/Aurora das subnets privadas"
  #   from_port   = 3306
  #   to_port     = 3306
  #   protocol    = "tcp"
  #   cidr_blocks = [aws_subnet.private[0].cidr_block, aws_subnet.private[1].cidr_block]
  # }

  # RDS não precisa de egress (não faz conexões de saída)
  # Removido egress para maior segurança

  tags = {
    Name = "rds-sg"
  }
}

# Security Group para Lambda (lambda-sg)
resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Security group para Lambda em VPC"
  vpc_id      = aws_vpc.main.id

  # Lambda não precisa de ingress (não recebe conexões)

  # Egress para acessar RDS (MySQL/Aurora)
  # Nota: Usamos CIDR das subnets privadas em vez de security_groups para evitar ciclo de dependências
  # A segurança é garantida pelo ingress do RDS que permite apenas dos security groups específicos
  egress {
    description = "MySQL/Aurora para RDS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }

  # Egress para acessar S3 (HTTPS)
  egress {
    description = "HTTPS para S3"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress para resolver DNS
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress geral (pode ser restringido conforme necessário)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-sg"
  }
}

