output "alb_dns_name" {
  description = "Endereço estável de entrada (ALB)"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint primário do PostgreSQL Multi-AZ"
  value       = module.rds.endpoint
}

output "app_instance_private_ips" {
  description = "IPs privados das instâncias de aplicação (app1 e app2)"
  value       = module.compute_app.private_ips
}

output "msg_instance_private_ip" {
  description = "IP privado da instância de mensageria (rp-2)"
  value       = module.compute_msg.private_ip
}

output "database_secret_arn" {
  description = "ARN do segredo de credenciais do banco"
  value       = module.secrets.database_secret_arn
}

output "ecr_registry_url" {
  description = "URL base do registro Amazon ECR da conta"
  value       = "${module.security.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ci_deployer_access_key_id" {
  description = "Access Key ID para configurar nos Secrets do GitHub Actions"
  value       = module.security.ci_deployer_access_key_id
}

output "ci_deployer_secret_access_key" {
  description = "Secret Access Key para configurar nos Secrets do GitHub Actions (use: terraform output -raw ci_deployer_secret_access_key)"
  value       = module.security.ci_deployer_secret_access_key
  sensitive   = true
}
