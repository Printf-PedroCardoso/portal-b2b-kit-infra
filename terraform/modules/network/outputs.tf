output "vpc_id" {
  description = "ID da VPC provisionada"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs das sub-redes públicas"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs das sub-redes privadas de aplicação"
  value       = aws_subnet.private_app[*].id
}

output "private_msg_subnet_id" {
  description = "ID da sub-rede privada de mensageria"
  value       = aws_subnet.private_msg.id
}

output "private_db_subnet_ids" {
  description = "IDs das sub-redes privadas de banco de dados"
  value       = aws_subnet.private_db[*].id
}

output "nat_gateway_ip" {
  description = "IP público estático associado ao NAT Gateway"
  value       = aws_eip.nat.public_ip
}
