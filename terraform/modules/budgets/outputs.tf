output "budget_id" {
  description = "ID do orçamento provisionado no AWS Budgets"
  value       = aws_budgets_budget.monthly.id
}

output "budget_name" {
  description = "Nome do orçamento no AWS Budgets"
  value       = aws_budgets_budget.monthly.name
}
