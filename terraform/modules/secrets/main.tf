# ==============================================================================
# Módulo de Gestão de Segredos - AWS Secrets Manager - RNF-19, RES-13, RNF-25
# ==============================================================================

resource "random_password" "svc_passwords" {
  for_each = toset([
    "usuarios", "produtos", "fornecimentos", "demanda",
    "mercado", "negociacao", "pedidos", "logistica", "transportadoras"
  ])
  length  = 24
  special = false
}

# 1. Segredo de Banco de Dados: Master e Roles DDL/DML por Serviço (RFI-09.1 a RFI-09.3)
resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.project_name}/${var.environment}/database"
  description             = "Credenciais segregadas de acesso ao PostgreSQL 16"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    admin_user     = "portal_admin"
    admin_password = var.db_admin_password
    ddl_user       = "portal_ddl"
    ddl_password   = var.db_ddl_password
    roles = {
      svc_usuarios        = random_password.svc_passwords["usuarios"].result
      svc_produtos        = random_password.svc_passwords["produtos"].result
      svc_fornecimentos   = random_password.svc_passwords["fornecimentos"].result
      svc_demanda         = random_password.svc_passwords["demanda"].result
      svc_mercado         = random_password.svc_passwords["mercado"].result
      svc_negociacao      = random_password.svc_passwords["negociacao"].result
      svc_pedidos         = random_password.svc_passwords["pedidos"].result
      svc_logistica       = random_password.svc_passwords["logistica"].result
      svc_transportadoras = random_password.svc_passwords["transportadoras"].result
    }
  })
}

# 2. Segredo de Autenticação JWT (RNF-17)
resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.project_name}/${var.environment}/auth-jwt"
  description             = "Chaves e segredos criptograficos para assinatura JWT"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    jwt_secret_key               = var.jwt_secret_key
    algorithm                    = "HS256"
    access_token_expire_minutes  = 15
    refresh_token_expire_minutes = 480
  })
}

# 3. Segredo do Redpanda SASL/SCRAM (RNF-20)
resource "random_password" "redpanda_scram" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redpanda" {
  name                    = "${var.project_name}/${var.environment}/redpanda"
  description             = "Credenciais SASL SCRAM para o cluster Redpanda"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redpanda" {
  secret_id = aws_secretsmanager_secret.redpanda.id
  secret_string = jsonencode({
    super_user     = "admin"
    super_password = random_password.redpanda_scram.result
    mechanism      = "SCRAM-SHA-256"
  })
}

# 4. Segredo do Redis compartilhado (denylist de tokens do Identity-Service - RNF-19, RES-13)
resource "random_password" "redis_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.project_name}/${var.environment}/redis"
  description             = "Credenciais de acesso ao Redis compartilhado (denylist Identity-Service)"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    password = random_password.redis_password.result
    port     = 6379
  })
}
