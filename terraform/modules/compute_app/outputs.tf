output "instance_ids" {
  description = "IDs das instâncias EC2 de aplicação"
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "Endereços IP privados das instâncias de aplicação"
  value       = aws_instance.app[*].private_ip
}
