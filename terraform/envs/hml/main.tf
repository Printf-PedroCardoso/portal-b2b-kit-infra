# ==============================================================================
# Ambiente de Homologação (HML) - Portal B2B Distribuído (INF-11, RES-04)
# ==============================================================================

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  environment = "hml"
  standard_tags = {
    Projeto     = var.project_name
    Ambiente    = local.environment
    Responsavel = "Equipe Infraestrutura"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.standard_tags
  }
}

# 1. Módulo de Rede
module "network" {
  source       = "../../modules/network"
  environment  = local.environment
  project_name = var.project_name
  tags         = local.standard_tags
}

# 2. Módulo de Segurança (Security Groups & IAM)
module "security" {
  source       = "../../modules/security"
  environment  = local.environment
  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  tags         = local.standard_tags
}

# 3. Módulo de Segredos
module "secrets" {
  source            = "../../modules/secrets"
  environment       = local.environment
  project_name      = var.project_name
  db_admin_password = var.db_admin_password
  db_ddl_password   = var.db_ddl_password
  jwt_secret_key    = var.jwt_secret_key
  tags              = local.standard_tags
}

# 4. Módulo de Banco de Dados RDS Multi-AZ
module "rds" {
  source                  = "../../modules/rds"
  environment             = local.environment
  project_name            = var.project_name
  admin_username          = "portal_admin"
  admin_password          = var.db_admin_password
  subnet_ids              = module.network.private_db_subnet_ids
  security_group_id       = module.security.rds_security_group_id
  allocated_storage       = 50
  max_allocated_storage   = 200
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true
  tags                    = local.standard_tags
}

# 5. Módulo de Observabilidade & WAF
module "observability" {
  source       = "../../modules/observability"
  environment  = local.environment
  project_name = var.project_name
  alert_email  = var.alert_email
  tags         = local.standard_tags
}

# 6. Módulo do Application Load Balancer
module "alb" {
  source            = "../../modules/alb"
  environment       = local.environment
  project_name      = var.project_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  domain_name       = var.domain_name
  waf_web_acl_arn   = module.observability.waf_web_acl_arn
  tags              = local.standard_tags
}

# 7. Módulo de Computação: Aplicações Ativo-Ativo (app1 e app2)
module "compute_app" {
  source                = "../../modules/compute_app"
  environment           = local.environment
  project_name          = var.project_name
  subnet_ids            = module.network.private_app_subnet_ids
  security_group_ids    = [module.security.app_security_group_id]
  iam_instance_profile  = module.security.ec2_instance_profile_name
  target_group_arn      = module.alb.target_group_arn
  user_data_script_path = "${path.module}/../../scripts/user_data_app.sh"
  tags                  = local.standard_tags
}

# 8. Módulo de Computação: Mensageria Redpanda rp-2
module "compute_msg" {
  source                = "../../modules/compute_msg"
  environment           = local.environment
  project_name          = var.project_name
  subnet_id             = module.network.private_msg_subnet_id
  security_group_ids    = [module.security.msg_security_group_id]
  iam_instance_profile  = module.security.ec2_instance_profile_name
  user_data_script_path = "${path.module}/../../scripts/user_data_msg.sh"
  tags                  = local.standard_tags
}

# 9. Módulo de Repositórios ECR
module "ecr" {
  source       = "../../modules/ecr"
  environment  = local.environment
  project_name = var.project_name
  tags         = local.standard_tags
}

# 10. Módulo de Governança Orçamentária
module "budgets" {
  source            = "../../modules/budgets"
  environment       = local.environment
  project_name      = var.project_name
  monthly_limit_usd = "500"
  subscriber_emails = [var.alert_email]
  tags              = local.standard_tags
}
