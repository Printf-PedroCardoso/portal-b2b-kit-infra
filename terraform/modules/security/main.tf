# ==============================================================================
# Módulo de Segurança (Security Groups e IAM de Privilégio Mínimo)
# Atende a INF-02, INF-07 e INF-08
# ==============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# 1. Security Groups (INF-02)
# ------------------------------------------------------------------------------

# 1.1 Security Group do ALB (Borda Pública)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Controle de acesso para o Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Entrada HTTP publica (redirecionada para HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Entrada HTTPS publica criptografada"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida irrestrita para comunicacao com alvos internos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Role = "LoadBalancer"
    }
  )
}

# 1.2 Security Group das Instâncias de Aplicação (app1 e app2)
# Proibida porta 22 (INF-02) e proibido 0.0.0.0/0 na entrada (INF-02)
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Controle de acesso para os servidores de aplicacao"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Trafego HTTP do gateway reverso recebido exclusivamente do ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Comunicacao Kafka/Redpanda e Schema Registry entre nos de app"
    from_port   = 18081
    to_port     = 19092
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Saida para NAT Gateway (atualizacoes e chamadas de servicos AWS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-sg"
      Role = "Application"
    }
  )
}

# 1.3 Security Group da Instância de Mensageria (Redpanda rp-2)
# Proibida porta 22 (INF-02) e proibido 0.0.0.0/0 na entrada
resource "aws_security_group" "msg" {
  name        = "${var.project_name}-${var.environment}-msg-sg"
  description = "Controle de acesso para o broker Redpanda dedicado"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Comunicacao Kafka/Redpanda originada das instancias de aplicacao"
    from_port       = 19092
    to_port         = 19092
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Acesso ao Schema Registry originado das instancias de aplicacao"
    from_port       = 18081
    to_port         = 18081
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Acesso ao Redis (denylist Identity-Service) originado exclusivamente das instancias de aplicacao"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Saida para NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-msg-sg"
      Role = "Messaging"
    }
  )
}

# Interconexão bidirecional Redpanda: autoriza app_sg a receber conexões do msg_sg
resource "aws_security_group_rule" "app_from_msg_redpanda" {
  type                     = "ingress"
  from_port                = 18081
  to_port                  = 19092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msg.id
  security_group_id        = aws_security_group.app.id
  description              = "Comunicacao Raft entre brokers originada da EC2 de mensageria"
}

# 1.4 Security Group do RDS PostgreSQL 16
# Entrada autorizada EXCLUSIVAMENTE originada do Security Group das aplicações (INF-02)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Controle estrito de acesso para o banco de dados RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Acesso ao banco PostgreSQL 5432 exclusivo para o app_sg"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
      Role = "Database"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. IAM de Privilégio Mínimo e Acesso via SSM (INF-07, INF-08)
# ------------------------------------------------------------------------------

# Função IAM para as instâncias EC2
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# INF-07: Permissão para AWS Systems Manager Session Manager (Elimina porta 22)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# INF-08: Política customizada com privilégio mínimo (sem *:*)
resource "aws_iam_policy" "ec2_least_privilege" {
  name        = "${var.project_name}-${var.environment}-ec2-least-privilege-policy"
  description = "Politica de menor privilegio para instancias EC2 (Secrets, ECR, CloudWatch)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Leitura exclusiva de segredos do ambiente
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
        ]
      },
      # Envio de logs e métricas para o CloudWatch
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" : "PortalB2B/${var.environment}"
          }
        }
      },
      # Download de imagens de containers do repositório ECR
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2_custom" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_least_privilege.arn
}

# Instance Profile associado às EC2
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
  tags = var.tags
}
