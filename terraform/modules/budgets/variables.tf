variable "environment" {
  type        = string
  description = "Nome do ambiente"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "portal-b2b"
}

variable "monthly_limit_usd" {
  type        = string
  description = "Limite orçamentário mensal em USD (RES-03: 500)"
  default     = "500"
}

variable "alert_threshold_percent" {
  type        = number
  description = "Percentual de gasto para disparo do alarme (INF-10: 80%)"
  default     = 80
}

variable "subscriber_emails" {
  type        = list(string)
  description = "Lista de e-mails para receber o alerta de orçamento"
  default     = ["financeiro-ops@portalb2b.local"]
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
