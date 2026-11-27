# 02. INFRAESTRUTURA COMO CÓDIGO (IaC) — TERRAFORM AWS

Este diretório contém a especificação completa e modularizada da infraestrutura de nuvem AWS para o **Portal B2B Distribuído**, atendendo aos requisitos de conformidade `INF-01` a `INF-12`, `RES-01` a `RES-11` e `RNF-01` a `RNF-43`.

---

## 1. Estrutura de Diretórios

```
terraform/
├── README.md                      # Este guia de referência e execução
├── scripts/
│   ├── user_data_app.sh           # Bootstrap das VMs de aplicação (INF-12)
│   └── user_data_msg.sh           # Bootstrap da VM de mensageria e Redis (INF-05, INF-12)
├── modules/                       # Módulos reutilizáveis e desacoplados
│   ├── network/                   # VPC, Subnets Multi-AZ, IGW, NAT GW (INF-01)
│   ├── security/                  # SGs sem porta 22 e IAM com menor privilégio (INF-02, INF-07, INF-08)
│   ├── compute_app/               # 2x EC2 t3.large Ubuntu 22.04 ativo-ativo (INF-04)
│   ├── compute_msg/               # 1x EC2 t3.large Redpanda rp-2 + Redis compartilhado (INF-05)
│   ├── rds/                       # PostgreSQL 16 Multi-AZ (INF-06, RNF-38)
│   ├── alb/                       # ALB público, health check /health/ready, TLS ACM (INF-03, RNF-16)
│   ├── secrets/                   # Segredos no AWS Secrets Manager: DB, JWT, Redpanda e Redis (RES-13, RNF-19, RNF-25)
│   ├── observability/             # CloudWatch Logs 30 dias KMS, Alarms e WAF (RNF-22, RNF-33, RNF-35, RNF-36)
│   ├── ecr/                       # Repositórios ECR com scan e tags imutáveis (INF-09)
│   └── budgets/                   # Alerta de orçamento a 80% de US$ 500 (INF-10, RES-03)
└── envs/                          # Parametrização por ambiente (INF-11, RES-04)
    ├── integracao/                # Integração inicial entre as equipes
    ├── hml/                       # Homologação e testes não funcionais
    └── prod/                      # Produção com proteção contra deleção
```

---

## 2. Mapeamento de Requisitos de Infraestrutura (INF-01 a INF-12)

| Requisito | Descrição | Recurso Terraform | Módulo |
|---|---|---|---|
| **INF-01** | VPC e Sub-redes Públicas/Privadas em ≥ 2 AZs | `aws_vpc`, `aws_subnet` (6 subnets em `us-east-2a`/`b`, AZs dinâmicas) | `modules/network` |
| **INF-02** | Security Groups dedicados sem porta 22 | `aws_security_group` (`alb_sg`, `app_sg`, `msg_sg`, `rds_sg`) | `modules/security` |
| **INF-03** | ALB com health check `/health/ready` e HTTP->HTTPS | `aws_lb`, `aws_lb_target_group`, `aws_lb_listener` | `modules/alb` |
| **INF-04** | 2 EC2 `t3.large` Ubuntu 22.04 gp3 50 GB em AZs distintas | `aws_instance` (2x), `aws_lb_target_group_attachment` | `modules/compute_app` |
| **INF-05** | 1 EC2 `t3.large` para Redpanda `rp-2` e Redis compartilhado (`6379`) | `aws_instance` (1x) em sub-rede privada com SG `msg_sg` | `modules/compute_msg` |
| **INF-06** | PostgreSQL 16 RDS Multi-AZ sem acesso público | `aws_db_instance` (multi_az = true, gp3 50 GB auto-scale) | `modules/rds` |
| **INF-07** | Acesso administrativo exclusivo via AWS SSM | `aws_iam_role_policy_attachment` (SSM Core, sem SSH) | `modules/security` |
| **INF-08** | IAM com privilégio mínimo (sem `*:*`) | `aws_iam_policy` (escopo restrito a segredos/ECR/logs) | `modules/security` |
| **INF-09** | Repositórios ECR com scan e tags imutáveis | `aws_ecr_repository` (immutable tags, scan_on_push) | `modules/ecr` |
| **INF-10** | Alerta de orçamento AWS Budgets a 80% de US$ 500 | `aws_budgets_budget` (limite US$ 500, threshold 80%) | `modules/budgets` |
| **INF-11** | Parametrização por ambiente e tags padrão | Estrutura `envs/` com tags `Projeto`, `Ambiente`, `Responsavel` | `envs/*` |
| **INF-12** | Bootstrap automatizado via user_data | Scripts `user_data_app.sh` e `user_data_msg.sh` | `scripts/` |

---

## 3. Pré-Requisitos de Execução

1. **Terraform CLI:** Versão $\ge$ 1.7.0 instalada (`terraform version`).
2. **AWS CLI v2:** Configurada com credenciais ativas (`aws sts get-caller-identity`).
3. **Permissões IAM:** Usuário ou role com privilégios para criar recursos de rede, computação, RDS, Secrets Manager, CloudWatch e IAM.
4. **Região e Ajustes Validados em Deploy Real:**
   - **Região (`us-east-2` — Ohio):** adotada devido à restrição de Service Control Policy (SCP) da organização AWS, mantendo a mesma tabela de preços de `us-east-1` e AZs derivadas dinamicamente (`<região>a` e `<região>b`).
   - **Descoberta de AMI via SSM:** `compute_app` e `compute_msg` obtêm a AMI oficial do Ubuntu 22.04 LTS via `data "aws_ssm_parameter"` (`/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id`), com variável opcional `ami_id` para override explícito.
   - **Associação WAF (`enable_waf`):** controlada por flag booleana em `modules/alb` para evitar erro de `count` dependente de ARN conhecido apenas após o `apply`.
   - **KMS para CloudWatch Logs:** `modules/observability` declara *key policy* explícita autorizando `logs.<região>.amazonaws.com` a criptografar os Log Groups.
   - **RDS PostgreSQL 16:** utiliza `engine_version = "16"` para seleção automática da versão *minor* suportada mais recente pela AWS.

---

## 4. Guia de Execução Passo a Passo

### 4.1 Escolha do Ambiente
Navegue para o diretório do ambiente desejado (exemplo: `integracao`):
```bash
cd terraform/envs/integracao
```

### 4.2 Configuração de Variáveis
Copie o template de variáveis de exemplo e configure valores seguros locais:
```bash
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```
*Atenção (Regra R3):* Nunca versione o arquivo `terraform.tfvars`. Assegure-se de que conste no `.gitignore`.

### 4.3 Inicialização (`init`)
Inicialize os módulos e provedores:
```bash
terraform init
```
*Para uso com backend remoto S3 (INF-11):*
Copie `backend.tf.example` para `backend.tf`, altere o nome do bucket para seu bucket único e execute:
```bash
terraform init -migrate-state
```

### 4.4 Formatação e Validação (`fmt` e `validate`)
Verifique a sintaxe e conformidade declarativa do código:
```bash
terraform fmt -check -recursive ../../
terraform validate
```

### 4.5 Planejamento da Infraestrutura (`plan`)
Gere o plano de execução para validar os recursos que serão criados:
```bash
terraform plan -out=tfplan
```

### 4.6 Aplicação (`apply`)
Aplique a infraestrutura na nuvem AWS:
```bash
terraform apply tfplan
```

### 4.7 Destruição Controlada (`destroy`)
Para encerrar todos os recursos e evitar custos quando o ambiente não estiver em uso:
```bash
terraform destroy -auto-approve
```
*(Nota: No ambiente `prod`, o banco RDS possui `deletion_protection = true`. Caso deseje destruir o ambiente de produção, desative esta flag em `envs/prod/main.tf` antes do destroy).*

---

## 5. Acesso Administrativo via AWS SSM (Sem Porta 22)

Para conectar-se de forma segura às instâncias privadas sem expor chaves SSH nem portas públicas:

```bash
# 1. Obter o ID da instância EC2 de aplicação app1
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=portal-b2b-integracao-app1" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

# 2. Iniciar sessão shell segura via AWS Systems Manager
aws ssm start-session --target "$INSTANCE_ID"

# 3. Encaminhamento de porta seguro para acessar o PgAdmin (5050) ou Kafka UI (8090)
aws ssm start-session --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5050"],"localPortNumber":["5050"]}'
```
Abra o navegador em `http://localhost:5050` para interagir com o PostgreSQL.
