# ==============================================================================
# IAM de Menor Privilegio para CI/CD (GitHub Actions) - Requisito INF-08
# Permite exclusivamente push no ECR (portal-b2b/*) e disparo de deploy via SSM
# nas instancias EC2 de aplicacao (app1 e app2) do ambiente.
# ==============================================================================

resource "aws_iam_user" "ci_deployer" {
  name = "${var.project_name}-${var.environment}-ci-deployer"
  path = "/ci-cd/"
  tags = var.tags
}

resource "aws_iam_access_key" "ci_deployer" {
  user = aws_iam_user.ci_deployer.name
}

resource "aws_iam_policy" "ci_deployer" {
  name        = "${var.project_name}-${var.environment}-ci-deployer-policy"
  description = "Permissoes minimas para GitHub Actions enviar imagens ao ECR e acionar deploy via SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Autenticacao no Amazon ECR
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      # 2. Push/Pull restrito aos repositorios do projeto Portal B2B
      {
        Sid    = "ECRPushProjectRepos"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/*"
        ]
      },
      # 3. Disparo de SSM SendCommand apenas com documento AWS-RunShellScript
      {
        Sid    = "SSMSendCommandDocument"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript"
        ]
      },
      # 4. Disparo de SSM SendCommand restrito as EC2 de aplicacao do ambiente
      {
        Sid    = "SSMSendCommandAppInstances"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Ambiente" = var.environment
            "aws:ResourceTag/Role"     = "Application"
          }
        }
      },
      # 5. Leitura do status e logs do comando SSM no GitHub Actions
      {
        Sid    = "SSMReadCommandStatus"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "ci_deployer" {
  user       = aws_iam_user.ci_deployer.name
  policy_arn = aws_iam_policy.ci_deployer.arn
}
