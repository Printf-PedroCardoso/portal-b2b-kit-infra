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

variable "subnet_id" {
  type        = string
  description = "ID da sub-rede privada de mensageria"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups associados (msg_sg)"
}

variable "iam_instance_profile" {
  type        = string
  description = "Nome do IAM Instance Profile"
}

variable "user_data_script_path" {
  type        = string
  description = "Caminho para o script user_data_msg.sh"
  default     = "../../scripts/user_data_msg.sh"
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
