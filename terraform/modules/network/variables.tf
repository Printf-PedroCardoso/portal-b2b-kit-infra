variable "environment" {
  type        = string
  description = "Nome do ambiente (integracao, hml, prod)"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto para identificação e prefixos de tags"
  default     = "portal-b2b"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR principal da VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Lista de no mínimo 2 Zonas de Disponibilidade (AZs). Se vazia, usa <região>a e <região>b automaticamente."
  default     = []
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Blocos CIDR para sub-redes públicas"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "Blocos CIDR para sub-redes privadas de aplicação"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_msg_subnet_cidr" {
  type        = string
  description = "Bloco CIDR para sub-rede privada de mensageria"
  default     = "10.0.20.0/24"
}

variable "private_db_subnet_cidrs" {
  type        = list(string)
  description = "Blocos CIDR para sub-redes privadas de banco de dados (RDS Multi-AZ)"
  default     = ["10.0.30.0/24", "10.0.31.0/24"]
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas obrigatórias"
  default     = {}
}
