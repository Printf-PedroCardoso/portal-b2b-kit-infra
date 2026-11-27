#!/usr/bin/env bash
# ==============================================================================
# Atualiza um unico microsservico na EC2 (chamado pelo GitHub Actions via SSM).
#
# Uso:
#   ./scripts/aws-deploy-service.sh <SERVICE_NAME> <IMAGE_TAG>
# Exemplo:
#   ./scripts/aws-deploy-service.sh produtos-service a1b2c3d
# ==============================================================================

set -euo pipefail

SERVICE_NAME="${1:?Informe o SERVICE_NAME (ex: produtos-service)}"
IMAGE_TAG="${2:?Informe a IMAGE_TAG (ex: hash do commit)}"
APP_DIR="/opt/portal-b2b"
ENV_FILE="${APP_DIR}/.env"
TAGS_FILE="${APP_DIR}/.env.tags"

# Allowlist de servicos permitidos
case "${SERVICE_NAME}" in
  usuarios-service)        TAG_VAR="TAG_USUARIOS_SERVICE" ;;
  produtos-service)        TAG_VAR="TAG_PRODUTOS_SERVICE" ;;
  fornecimentos-service)   TAG_VAR="TAG_FORNECIMENTOS_SERVICE" ;;
  demanda-service)         TAG_VAR="TAG_DEMANDA_SERVICE" ;;
  mercado-service)         TAG_VAR="TAG_MERCADO_SERVICE" ;;
  negociacao-service)      TAG_VAR="TAG_NEGOCIACAO_SERVICE" ;;
  pedidos-service)         TAG_VAR="TAG_PEDIDOS_SERVICE" ;;
  logistica-service)       TAG_VAR="TAG_LOGISTICA_SERVICE" ;;
  transportadoras-service) TAG_VAR="TAG_TRANSPORTADORAS_SERVICE" ;;
  *)
    echo "ERRO: Servico '${SERVICE_NAME}' nao esta na lista permitida." >&2
    exit 1
    ;;
esac

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERRO: ${ENV_FILE} nao encontrado. Execute aws-sync-env.sh primeiro." >&2
  exit 1
fi

cd "${APP_DIR}"
# Carrega AWS_REGION e ECR_REGISTRY
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

echo "==> [$(hostname)] Fazendo login no Amazon ECR (${ECR_REGISTRY})..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

touch "${TAGS_FILE}"
chmod 600 "${TAGS_FILE}"

# Atualiza ou adiciona a tag do servico em .env.tags
if grep -q "^${TAG_VAR}=" "${TAGS_FILE}"; then
  sed -i "s|^${TAG_VAR}=.*|${TAG_VAR}=${IMAGE_TAG}|" "${TAGS_FILE}"
else
  echo "${TAG_VAR}=${IMAGE_TAG}" >> "${TAGS_FILE}"
fi

echo "==> [$(hostname)] Baixando imagem ${ECR_REGISTRY}/portal-b2b/${SERVICE_NAME}:${IMAGE_TAG}..."
docker compose -f docker-compose.aws.yml --env-file "${ENV_FILE}" --env-file "${TAGS_FILE}" pull "${SERVICE_NAME}"

echo "==> [$(hostname)] Subindo container ${SERVICE_NAME}..."
docker compose -f docker-compose.aws.yml --env-file "${ENV_FILE}" --env-file "${TAGS_FILE}" up -d --no-deps --force-recreate "${SERVICE_NAME}"

sleep 5
echo "==> [$(hostname)] Status do container:"
docker ps --filter "name=^/${SERVICE_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo "==> [$(hostname)] Ultimas 40 linhas de log de ${SERVICE_NAME}:"
docker logs --tail 40 "${SERVICE_NAME}" 2>&1 || true

# Verifica se o container continua rodando (evita falso positivo se crashou no boot)
if ! docker ps --filter "name=^/${SERVICE_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
  echo "ERRO: Container ${SERVICE_NAME} nao permaneceu em execucao apos o deploy!" >&2
  exit 1
fi

echo "==> [$(hostname)] Deploy de ${SERVICE_NAME}:${IMAGE_TAG} concluido com sucesso!"
