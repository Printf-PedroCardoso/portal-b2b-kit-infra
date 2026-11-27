variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "log_retention_days" {
  type        = number
  description = "Dias de retenção dos logs no CloudWatch (RNF-36: 30 dias)"
  default     = 30
}

variable "alert_email" {
  type        = string
  description = "E-mail de destino para notificações críticas via SNS"
  default     = "ops-alertas@portalb2b.local"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix do ALB para métricas CloudWatch"
  default     = ""
}

variable "target_group_arn_suffix" {
  type        = string
  description = "ARN suffix do Target Group para métricas CloudWatch"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
