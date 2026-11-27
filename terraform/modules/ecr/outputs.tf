output "repository_urls" {
  description = "Mapa de nomes de serviço para URLs dos repositórios ECR"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "repository_arns" {
  description = "Mapa de nomes de serviço para ARNs dos repositórios ECR"
  value       = { for k, v in aws_ecr_repository.repos : k => v.arn }
}
