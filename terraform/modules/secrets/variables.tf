variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "db_admin_password" {
  type        = string
  description = "Senha do usuário administrador portal_admin"
  sensitive   = true
}

variable "db_ddl_password" {
  type        = string
  description = "Senha da role DDL portal_ddl"
  sensitive   = true
}

variable "jwt_secret_key" {
  type        = string
  description = "Chave secreta ou privada para emissão de JWT"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
