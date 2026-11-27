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
  description = "Nome de domínio para o ambiente"
  default     = "integracao.b2b.local"
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
  default     = "integracao-ops@portalb2b.local"
}

variable "ami_id" {
  type        = string
  description = "ID explícito da AMI Ubuntu 22.04 LTS (opcional; se vazio, busca via SSM Parameter Store)"
  default     = ""
}
