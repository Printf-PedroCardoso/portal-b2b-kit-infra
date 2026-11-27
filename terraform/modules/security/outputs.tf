output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID do Security Group das instâncias de aplicação"
  value       = aws_security_group.app.id
}

output "msg_security_group_id" {
  description = "ID do Security Group da instância de mensageria"
  value       = aws_security_group.msg.id
}

output "rds_security_group_id" {
  description = "ID do Security Group do banco de dados RDS"
  value       = aws_security_group.rds.id
}

output "ec2_instance_profile_name" {
  description = "Nome do Instance Profile IAM associado às EC2"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_iam_role_arn" {
  description = "ARN da Role IAM das instâncias EC2"
  value       = aws_iam_role.ec2.arn
}

output "ci_deployer_access_key_id" {
  description = "Access Key ID do usuário IAM para GitHub Actions"
  value       = aws_iam_access_key.ci_deployer.id
}

output "ci_deployer_secret_access_key" {
  description = "Secret Access Key do usuário IAM para GitHub Actions"
  value       = aws_iam_access_key.ci_deployer.secret
  sensitive   = true
}

output "aws_account_id" {
  description = "ID da conta AWS atual"
  value       = data.aws_caller_identity.current.account_id
}
