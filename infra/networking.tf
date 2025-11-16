# ============================================================================
# networking.tf - Infraestrutura de Rede (VPC, Subnets, Gateways)
# ============================================================================
# Este arquivo cria toda a infraestrutura de rede necessária:
# - VPC: Rede isolada na AWS
# - Subnets: Divisões da VPC (públicas e privadas)
# - Internet Gateway: Acesso à internet para subnets públicas
# - NAT Gateway: Acesso controlado à internet para subnets privadas
# - Route Tables: Define como o tráfego é roteado
# ============================================================================

# VPC (Virtual Private Cloud)
# Cria uma rede isolada na AWS onde todos os recursos serão criados
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr  # Ex: 10.0.0.0/16 (65.536 IPs)
  enable_dns_hostnames = true          # Permite usar nomes DNS para recursos
  enable_dns_support   = true          # Habilita resolução DNS na VPC

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway (IGW)
# Permite que recursos em subnets públicas acessem a internet diretamente
# Necessário para ALB, EC2 frontend, etc.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Subnets Públicas
# Recursos aqui recebem IP público automaticamente e podem acessar internet
# Uso: ALB, EC2 frontend, bastion hosts
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)  # Cria 2 subnets (uma por AZ)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)  # 10.0.1.0/24, 10.0.2.0/24
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Atribui IP público automaticamente

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Subnets Privadas
# Recursos aqui NÃO recebem IP público e acessam internet via NAT Gateway
# Uso: RDS, Lambdas em VPC, ECS tasks (mais seguro)
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)  # Cria 2 subnets (uma por AZ)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))  # 10.0.3.0/24, 10.0.4.0/24
  availability_zone = var.availability_zones[count.index]
  # map_public_ip_on_launch = false (padrão) - sem IP público

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# Elastic IP para NAT Gateway
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table Pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Privadas
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }

}

# Route Table Associations - Públicas
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations - Privadas
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}


