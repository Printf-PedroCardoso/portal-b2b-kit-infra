# ==============================================================================
# Módulo de Computação - Mensageria Redpanda rp-2 Dedicado - Requisito INF-05
# ==============================================================================

# Busca dinâmica da AMI oficial mais recente do Ubuntu 22.04 LTS via SSM Parameter Store (RES-05)
# Usa ssm:GetParameter em vez de ec2:DescribeImages para compatibilidade com SCPs restritivas
data "aws_ssm_parameter" "ubuntu" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "msg" {
  ami                    = var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.ubuntu[0].value)
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile

  # Volume raiz EBS gp3 50 GB criptografado (INF-05, RES-11)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-msg-root"
      }
    )
  }

  user_data = fileexists(var.user_data_script_path) ? file(var.user_data_script_path) : null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-msg-rp2"
      Role = "Messaging"
      Node = "rp-2"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}
