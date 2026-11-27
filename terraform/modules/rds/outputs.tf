output "db_instance_id" {
  description = "Identificador da instância RDS"
  value       = aws_db_instance.this.identifier
}

output "endpoint" {
  description = "Endpoint de conexão primária (DNS estável do RDS)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname de conexão do RDS (sem porta)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta de conexão do banco de dados"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Nome do banco de dados lógico"
  value       = aws_db_instance.this.db_name
}
