output "alb_dns_name" {
  description = "Endereço oficial de produção (ALB)"
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
