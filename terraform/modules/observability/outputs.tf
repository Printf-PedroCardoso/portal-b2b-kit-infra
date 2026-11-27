output "apps_log_group_name" {
  description = "Nome do Log Group de aplicações"
  value       = aws_cloudwatch_log_group.apps.name
}

output "apps_log_group_arn" {
  description = "ARN do Log Group de aplicações"
  value       = aws_cloudwatch_log_group.apps.arn
}

output "sns_topic_arn" {
  description = "ARN do tópico SNS de alarmes"
  value       = aws_sns_topic.alerts.arn
}

output "waf_web_acl_arn" {
  description = "ARN da Web ACL do AWS WAF"
  value       = aws_wafv2_web_acl.this.arn
}
