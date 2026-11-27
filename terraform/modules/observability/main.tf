# ==============================================================================
# Módulo de Observabilidade e Monitoramento - RNF-22, RNF-33, RNF-35, RNF-36
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Chave KMS para criptografia em repouso dos logs (RNF-36)
resource "aws_kms_key" "logs" {
  description             = "Chave KMS para criptografia do CloudWatch Log Group"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}/${var.environment}/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# 1. CloudWatch Log Group com retenção de 30 dias e criptografia KMS (RNF-36)
resource "aws_cloudwatch_log_group" "apps" {
  name              = "/aws/ec2/${var.project_name}/${var.environment}/apps"
  retention_in_days = var.log_retention_days # 30 dias
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-apps-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "redpanda" {
  name              = "/aws/ec2/${var.project_name}/${var.environment}/redpanda"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redpanda-logs"
    }
  )
}

# 2. Tópico SNS para Notificações de Alarme (RNF-35)
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts-topic"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 3. Alarme de Falha em Instâncias de Aplicação (RNF-02, RNF-05, RNF-35)
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count               = var.target_group_arn_suffix != "" && var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 10 # 2 avaliações detectam em <= 15s (RNF-02)
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Dispara quando ao menos 1 instancia de aplicacao falha no health check profundo"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# 4. Alarme de Consumer Lag do Redpanda > 1000 por 2 minutos (RNF-33)
resource "aws_cloudwatch_metric_alarm" "kafka_consumer_lag" {
  alarm_name          = "${var.project_name}-${var.environment}-kafka-consumer-lag-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConsumerLag"
  namespace           = "PortalB2B/${var.environment}"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1000
  alarm_description   = "Alerta se o atraso de consumo de eventos exceder 1000 mensagens por 2 minutos"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# 5. AWS WAF Web ACL com Regras Gerenciadas (RNF-22)
resource "aws_wafv2_web_acl" "this" {
  name        = "${var.project_name}-${var.environment}-waf"
  description = "WAF com protecao Common Rule Set e Known Bad Inputs para ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Regra Gerenciada AWS: Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regra Gerenciada AWS: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}
