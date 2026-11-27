variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "db_instance_class" {
  type        = string
  description = "Tipo de instância do RDS (ex: db.t4g.medium)"
  default     = "db.t4g.medium"
}

variable "multi_az" {
  type        = bool
  description = "Habilitar implantação Multi-AZ no RDS (INF-06)"
  default     = true
}

variable "storage_type" {
  type        = string
  description = "Tipo de storage EBS do RDS (gp3 ou gp2)"
  default     = "gp3"
}

variable "database_name" {
  type        = string
  description = "Nome do banco de dados lógico inicial"
  default     = "portal_b2b"
}

variable "admin_username" {
  type        = string
  description = "Usuário mestre administrativo do PostgreSQL (portal_admin)"
  default     = "portal_admin"
}

variable "admin_password" {
  type        = string
  description = "Senha mestre do banco de dados (injetada via Secrets Manager)"
  sensitive   = true
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs das sub-redes privadas de banco em AZs distintas para Multi-AZ"
}

variable "security_group_id" {
  type        = string
  description = "ID do Security Group rds_sg"
}

variable "allocated_storage" {
  type        = number
  description = "Espaço inicial alocado em GB"
  default     = 50
}

variable "max_allocated_storage" {
  type        = number
  description = "Limite máximo de expansão automática de storage em GB"
  default     = 200
}

variable "backup_retention_period" {
  type        = number
  description = "Período de retenção de backups diários em dias (INF-06: 7 dias)"
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Habilitar proteção contra exclusão acidental"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Ignorar snapshot final ao destruir o recurso"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
