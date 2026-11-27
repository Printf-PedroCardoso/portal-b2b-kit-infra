variable "aws_region" {
  type        = string
  description = "Região da AWS permitida pela SCP da conta (us-east-2)"
  default     = "us-east-2"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "domain_name" {
  type        = string
  description = "Nome de domínio oficial para produção"
  default     = "portal.b2b.com.br"
}

variable "db_admin_password" {
  type        = string
  description = "Senha administrativa master do RDS PostgreSQL"
  sensitive   = true
}

variable "db_ddl_password" {
  type        = string
  description = "Senha do usuário de migração portal_ddl"
  sensitive   = true
}

variable "jwt_secret_key" {
  type        = string
  description = "Chave secreta para assinatura JWT"
  sensitive   = true
}

variable "alert_email" {
  type        = string
  description = "E-mail de alerta para monitoramento e orçamento"
  default     = "noc-alertas@portalb2b.com.br"
}
