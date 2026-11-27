#!/usr/bin/env bash
# ==============================================================================
# Sincroniza segredos do AWS Secrets Manager para /opt/portal-b2b/.env
# Executado nas EC2 app1 e app2 (usa a IAM Role da propria instancia).
#
# Uso:
#   ./scripts/aws-sync-env.sh <RDS_HOST> <MSG_PRIVATE_IP> <ECR_REGISTRY> [AWS_REGION] [ENVIRONMENT]
# ==============================================================================

set -euo pipefail

RDS_HOST="${1:?Informe o RDS_HOST (sem :5432)}"
MSG_PRIVATE_IP="${2:?Informe o IP privado da EC2 de mensageria (rp-2)}"
ECR_REGISTRY="${3:?Informe o ECR_REGISTRY (ex: 123456789012.dkr.ecr.us-east-2.amazonaws.com)}"
AWS_REGION="${4:-us-east-2}"
ENVIRONMENT="${5:-integracao}"
PROJECT_NAME="portal-b2b"
APP_DIR="/opt/portal-b2b"

# Remove porta caso o output do RDS venha no formato host:5432
RDS_HOST="${RDS_HOST%%:*}"

echo "==> Buscando segredos no AWS Secrets Manager (${PROJECT_NAME}/${ENVIRONMENT}/*)..."

DB_JSON=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/database" \
  --query SecretString --output text)

JWT_JSON=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/auth-jwt" \
  --query SecretString --output text)

REDIS_JSON=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/redis" \
  --query SecretString --output text)

ENV_FILE="${APP_DIR}/.env"
TAGS_FILE="${APP_DIR}/.env.tags"

cat > "${ENV_FILE}" <<EOF
# Gerado automaticamente por aws-sync-env.sh em $(date -u +"%Y-%m-%dT%H:%M:%SZ")
AWS_REGION=${AWS_REGION}
ENVIRONMENT=${ENVIRONMENT}
ECR_REGISTRY=${ECR_REGISTRY}

RDS_HOST=${RDS_HOST}
DB_PORT=5432
DB_NAME=portal_b2b
MSG_PRIVATE_IP=${MSG_PRIVATE_IP}
REDIS_PORT=$(echo "${REDIS_JSON}" | jq -r '.port')
REDIS_PASSWORD=$(echo "${REDIS_JSON}" | jq -r '.password')

JWT_SECRET_KEY=$(echo "${JWT_JSON}" | jq -r '.jwt_secret_key')
JWT_ALGORITHM=$(echo "${JWT_JSON}" | jq -r '.algorithm')
ACCESS_TOKEN_EXPIRE_MINUTES=$(echo "${JWT_JSON}" | jq -r '.access_token_expire_minutes')

DB_ADMIN_USER=$(echo "${DB_JSON}" | jq -r '.admin_user')
DB_ADMIN_PASSWORD=$(echo "${DB_JSON}" | jq -r '.admin_password')
DB_PASS_SVC_USUARIOS=$(echo "${DB_JSON}" | jq -r '.roles.svc_usuarios')
DB_PASS_SVC_PRODUTOS=$(echo "${DB_JSON}" | jq -r '.roles.svc_produtos')
DB_PASS_SVC_FORNECIMENTOS=$(echo "${DB_JSON}" | jq -r '.roles.svc_fornecimentos')
DB_PASS_SVC_DEMANDA=$(echo "${DB_JSON}" | jq -r '.roles.svc_demanda')
DB_PASS_SVC_MERCADO=$(echo "${DB_JSON}" | jq -r '.roles.svc_mercado')
DB_PASS_SVC_NEGOCIACAO=$(echo "${DB_JSON}" | jq -r '.roles.svc_negociacao')
DB_PASS_SVC_PEDIDOS=$(echo "${DB_JSON}" | jq -r '.roles.svc_pedidos')
DB_PASS_SVC_LOGISTICA=$(echo "${DB_JSON}" | jq -r '.roles.svc_logistica')
DB_PASS_SVC_TRANSPORTADORAS=$(echo "${DB_JSON}" | jq -r '.roles.svc_transportadoras')
EOF

chmod 600 "${ENV_FILE}"
touch "${TAGS_FILE}"
chmod 600 "${TAGS_FILE}"

echo "==> Arquivo ${ENV_FILE} gerado com sucesso (permissao 600)."
