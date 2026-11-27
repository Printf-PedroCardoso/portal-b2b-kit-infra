# ==============================================================================
# Módulo de Computação - Aplicações Ativo-Ativo (app1 e app2) - Requisito INF-04
# ==============================================================================

# Busca dinâmica da AMI oficial mais recente do Ubuntu 22.04 LTS via SSM Parameter Store (RES-05)
# Usa ssm:GetParameter em vez de ec2:DescribeImages para compatibilidade com SCPs restritivas
data "aws_ssm_parameter" "ubuntu" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Provisionamento das 2 instâncias em AZs distintas (Multi-AZ Ativo-Ativo)
# Nenhuma chave SSH declarada (key_name ausente conforme INF-07)
resource "aws_instance" "app" {
  count                  = 2
  ami                    = var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.ubuntu[0].value)
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile

  # Volume raiz EBS gp3 50 GB criptografado (INF-04, RES-11)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-app${count.index + 1}-root"
      }
    )
  }

  user_data = fileexists(var.user_data_script_path) ? file(var.user_data_script_path) : null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 obrigatório para segurança reforçada
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app${count.index + 1}"
      Role = "Application"
      Node = "app${count.index + 1}"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}

# Registro das instâncias app1 e app2 no Target Group do ALB (INF-04)
resource "aws_lb_target_group_attachment" "app" {
  count            = 2
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = 8080
}
