output "database_secret_arn" {
  description = "ARN do segredo de credenciais do banco de dados"
  value       = aws_secretsmanager_secret.database.arn
}

output "jwt_secret_arn" {
  description = "ARN do segredo de JWT"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "redpanda_secret_arn" {
  description = "ARN do segredo do Redpanda"
  value       = aws_secretsmanager_secret.redpanda.arn
}

output "redis_secret_arn" {
  description = "ARN do segredo do Redis compartilhado"
  value       = aws_secretsmanager_secret.redis.arn
}

output "redis_secret_name" {
  description = "Nome do segredo do Redis compartilhado"
  value       = aws_secretsmanager_secret.redis.name
}

output "database_secret_name" {
  description = "Nome do segredo de banco"
  value       = aws_secretsmanager_secret.database.name
}
