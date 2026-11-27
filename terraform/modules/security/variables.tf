variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC"
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
