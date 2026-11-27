# ==============================================================================
# Módulo de Banco de Dados - PostgreSQL 16 RDS Multi-AZ - Requisito INF-06
# ==============================================================================

# Grupo de Sub-redes do RDS (Distribuído em AZs distintas para Multi-AZ)
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-dbsubnet-group"
  description = "Grupo de sub-redes privadas para PostgreSQL Multi-AZ"
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-dbsubnet-group"
    }
  )
}

# Parameter Group customizado para PostgreSQL 16
resource "aws_db_parameter_group" "this" {
  name        = "${var.project_name}-${var.environment}-pg16-params"
  family      = "postgres16"
  description = "Parametros otimizados para PostgreSQL 16 Portal B2B"

  # Obriga uso de TLS para conexões de clientes (RNF-20)
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Configura logging de comandos com lentidão para observabilidade
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # ms
  }

  tags = var.tags
}

# Instância RDS PostgreSQL Multi-AZ (Primário + Standby síncrono em AZ oposta)
resource "aws_db_instance" "this" {
  identifier                 = "${var.project_name}-${var.environment}-rds"
  engine                     = "postgres"
  engine_version             = "16"
  instance_class             = var.db_instance_class
  multi_az                   = var.multi_az # INF-06: 2 servidores (primário + standby)
  publicly_accessible        = false        # INF-06: sem acesso público
  storage_encrypted          = true         # INF-06: criptografia de storage
  storage_type               = var.storage_type
  allocated_storage          = var.allocated_storage       # INF-06: 50 GB inicial
  max_allocated_storage      = var.max_allocated_storage   # INF-06: expansão automática até 200 GB
  backup_retention_period    = var.backup_retention_period # INF-06: 7 dias
  db_name                    = var.database_name
  username                   = var.admin_username
  password                   = var.admin_password
  db_subnet_group_name       = aws_db_subnet_group.this.name
  parameter_group_name       = aws_db_parameter_group.this.name
  vpc_security_group_ids     = [var.security_group_id]
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds"
      Role = "Database"
    }
  )

  lifecycle {
    ignore_changes = [password]
  }
}
