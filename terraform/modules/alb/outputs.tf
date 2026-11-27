output "alb_id" {
  description = "ID do Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS estável gerado pelo ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Canonical Hosted Zone ID do ALB"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN do Target Group das aplicações"
  value       = aws_lb_target_group.app.arn
}
