# Data source para buscar a AMI mais recente do Amazon Linux
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Key Pair (crie manualmente ou via AWS Console)
# resource "aws_key_pair" "main" {
#   key_name   = "${var.project_name}-key"
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# Instância EC2 Frontend
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.frontend.id]

  # user_data = <<-EOF
  #   #!/bin/bash
  #   yum update -y
  #   yum install -y httpd
  #   systemctl start httpd
  #   systemctl enable httpd
  # EOF

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# Elastic IP para EC2 (opcional)
resource "aws_eip" "frontend" {
  instance = aws_instance.frontend.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-frontend-eip"
  }
}

