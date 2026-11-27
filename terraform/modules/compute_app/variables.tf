variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "ami_id" {
  type        = string
  description = "ID explícito da AMI Ubuntu 22.04 LTS (opcional; se vazio, busca via SSM Parameter Store)"
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2 (RES-11: t3.large)"
  default     = "t3.large"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Lista de 2 sub-redes privadas de aplicação em AZs distintas"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups associados (app_sg)"
}

variable "iam_instance_profile" {
  type        = string
  description = "Nome do IAM Instance Profile"
}

variable "target_group_arn" {
  type        = string
  description = "ARN do Target Group do ALB para registro das instâncias"
}

variable "user_data_script_path" {
  type        = string
  description = "Caminho para o script user_data_app.sh"
  default     = "../../scripts/user_data_app.sh"
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
