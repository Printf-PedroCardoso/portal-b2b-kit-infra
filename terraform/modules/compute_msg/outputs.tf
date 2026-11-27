output "instance_id" {
  description = "ID da instância EC2 de mensageria"
  value       = aws_instance.msg.id
}

output "private_ip" {
  description = "Endereço IP privado da instância de mensageria"
  value       = aws_instance.msg.private_ip
}
