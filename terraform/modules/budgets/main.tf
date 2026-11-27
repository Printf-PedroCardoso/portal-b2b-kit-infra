# ==============================================================================
# Módulo de Governança Orçamentária - AWS Budgets - Requisito INF-10 e RES-03
# ==============================================================================

resource "aws_budgets_budget" "monthly" {
  name              = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_limit_usd
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  # Alerta 1: Gasto Real (Actual) atingindo 80% do teto estipulado (US$ 400 de US$ 500)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.alert_threshold_percent # INF-10: 80%
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.subscriber_emails
  }

  # Alerta 2: Projeção de Gasto (Forecasted) prevendo estouro de 100%
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.subscriber_emails
  }

  tags = var.tags
}
