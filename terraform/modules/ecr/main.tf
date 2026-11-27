# ==============================================================================
# Módulo de Registro de Imagens - Amazon ECR - Requisito INF-09
# ==============================================================================

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.repositories)
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # INF-09: tags imutáveis para rastreabilidade

  image_scanning_configuration {
    scan_on_push = true # INF-09: varredura automática de vulnerabilidades
  }

  tags = merge(
    var.tags,
    {
      Component = each.key
    }
  )
}

# Política de ciclo de vida para reter as 30 imagens mais recentes e evitar custos desnecessários
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = toset(var.repositories)
  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Reter apenas as ultimas 30 imagens com tag"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
