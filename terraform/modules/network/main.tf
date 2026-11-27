# ==============================================================================
# Módulo de Rede (VPC e Sub-redes Multi-AZ) - Requisito INF-01
# ==============================================================================

data "aws_region" "current" {}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}b",
  ]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# Internet Gateway para tráfego público de entrada e saída
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# Sub-redes Públicas (Ingresso do ALB) em 2 AZs distintas
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
      Type = "Public"
    }
  )
}

# Elastic IP e NAT Gateway para permitir tráfego de saída das sub-redes privadas
# Premissa PA-01: 1 NAT Gateway na primeira AZ (ex: us-east-2a) para otimização de custo (teto US$ 500)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-gw"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# Tabela de Rotas Públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Sub-redes Privadas de Aplicação (app1 e app2) em AZs distintas
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-app-${count.index + 1}"
      Type = "PrivateApp"
    }
  )
}

# Sub-rede Privada de Mensageria (Redpanda rp-2 dedicado)
resource "aws_subnet" "private_msg" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_msg_subnet_cidr
  availability_zone = local.azs[0]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-msg"
      Type = "PrivateMsg"
    }
  )
}

# Sub-redes Privadas de Banco de Dados (RDS Multi-AZ: primário e standby)
resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-db-${count.index + 1}"
      Type = "PrivateDb"
    }
  )
}

# Tabela de Rotas Privadas (Direcionando 0.0.0.0/0 para o NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
    }
  )
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_msg" {
  subnet_id      = aws_subnet.private_msg.id
  route_table_id = aws_route_table.private.id
}

# DB Subnets não necessitam rota de saída para a Internet (isolamento estrito)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-database-rt"
    }
  )
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.database.id
}
