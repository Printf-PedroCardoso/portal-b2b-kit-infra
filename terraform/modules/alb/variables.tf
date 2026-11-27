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

variable "public_subnet_ids" {
  type        = list(string)
  description = "Lista de sub-redes públicas para o ALB (mínimo 2 em AZs distintas)"
}

variable "security_group_id" {
  type        = string
  description = "ID do Security Group alb_sg"
}

variable "domain_name" {
  type        = string
  description = "Nome de domínio para o certificado ACM e DNS Route 53 (ex: b2b.exemplo.com)"
  default     = "b2b.local"
}

variable "route53_zone_id" {
  type        = string
  description = "ID da Hosted Zone no Route 53 (opcional)"
  default     = ""
}

variable "certificate_arn" {
  type        = string
  description = "ARN do certificado ACM existente (se vazio, um certificado autoassinado/de teste será gerado)"
  default     = ""
}

variable "enable_waf" {
  type        = bool
  description = "Habilita a associação da Web ACL do AWS WAF ao ALB (RNF-22)"
  default     = true
}

variable "waf_web_acl_arn" {
  type        = string
  description = "ARN da Web ACL do AWS WAF para associar ao ALB (RNF-22)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags padronizadas"
  default     = {}
}
