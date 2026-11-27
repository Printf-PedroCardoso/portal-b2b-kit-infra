variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "repositories" {
  type        = list(string)
  description = "Lista dos nomes de repositórios ECR a criar"
  default = [
    "gateway",
    "usuarios-service",
    "produtos-service",
    "fornecimentos-service",
    "demanda-service",
    "mercado-service",
    "negociacao-service",
    "pedidos-service",
    "logistica-service",
    "transportadoras-service",
    "frontend-usuarios",
    "frontend-produtos",
    "frontend-fornecimentos",
    "frontend-demanda",
    "frontend-negociacao",
    "frontend-pedidos",
    "frontend-logistica"
  ]
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
