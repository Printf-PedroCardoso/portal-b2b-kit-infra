# ==============================================================================
# Módulo de Borda - Application Load Balancer (ALB) - Requisito INF-03 e RNF-16
# ==============================================================================

# Application Load Balancer público Multi-AZ
resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
      Role = "LoadBalancer"
    }
  )
}

# Target Group com Health Check Profundo (/health/ready) - INF-03, RNF-02, RNF-05
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health/ready" # RNF-05: checagem profunda
    port                = "8080"
    protocol            = "HTTP"
    interval            = 5 # RNF-02: detecção em até 15s (5s x 3 falhas)
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 15

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-tg"
    }
  )
}

# Listener HTTP Porta 80 - Redirecionamento 301 Obrigatório para HTTPS (RNF-16)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# Certificado ACM: se var.certificate_arn não for fornecido, cria par de chaves e importa no ACM
resource "tls_private_key" "self_signed" {
  count     = var.certificate_arn == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count           = var.certificate_arn == "" ? 1 : 0
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "Portal B2B Inc."
  }

  validity_period_hours = 8760 # 1 ano

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "aws_acm_certificate" "imported" {
  count            = var.certificate_arn == "" ? 1 : 0
  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cert"
    }
  )
}

locals {
  effective_cert_arn = var.certificate_arn != "" ? var.certificate_arn : aws_acm_certificate.imported[0].arn
}

# Listener HTTPS Porta 443 com Certificado ACM e Encaminhamento para o Target Group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.effective_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = var.tags
}

# Registro no Route 53 (Alias estável para o ALB - D-04, INF-03)
resource "aws_route53_record" "app" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

# Associação do AWS WAF com o ALB (RNF-22)
resource "aws_wafv2_web_acl_association" "this" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}
