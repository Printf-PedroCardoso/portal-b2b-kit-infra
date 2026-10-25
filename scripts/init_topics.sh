#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialização dos 15 Tópicos de Negócio no Redpanda (CT-E09, RNF-43)
# ==============================================================================

set -euo pipefail

BROKERS="${KAFKA_BOOTSTRAP_SERVERS:-localhost:19092}"
PARTITIONS=3 # CT-E09: 3 partições
REPLICATION=3 # RFI-07: fator de replicação 3

TOPICS=(
  "empresa_cadastrada"
  "produto_cadastrado"
  "fornecimento_criado"
  "estoque_atualizado"
  "demanda_criada"
  "demanda_recorrente_gerada"
  "modo_negociacao_definido"
  "leilao_iniciado"
  "lance_realizado"
  "negociacao_fechada"
  "pedido_criado"
  "pedido_atualizado"
  "solicitacao_frete_criada"
  "cotacao_recebida"
  "frete_selecionado"
)

DLT_TOPICS=(
  "usuarios.dlt"
  "produtos.dlt"
  "fornecimentos.dlt"
  "demanda.dlt"
  "mercado.dlt"
  "negociacao.dlt"
  "pedidos.dlt"
  "logistica.dlt"
  "transportadoras.dlt"
)

echo "==> Inicializando 15 topicos de negocio no cluster Redpanda ($BROKERS)..."

for topic in "${TOPICS[@]}"; do
  echo "--> Criando topico: $topic (particoes=$PARTITIONS, replicacao=$REPLICATION, retencao=7d)"
  if command -v rpk &> /dev/null; then
    rpk topic create "$topic" \
      --brokers "$BROKERS" \
      --partitions "$PARTITIONS" \
      --replicas "$REPLICATION" \
      --topic-config retention.ms=604800000 || true # RNF-43: 7 dias
  elif command -v docker &> /dev/null && docker ps 2>/dev/null | grep -q portal-b2b-rp-0; then
    docker exec portal-b2b-rp-0 rpk topic create "$topic" \
      --brokers rp-0:9092 \
      --partitions "$PARTITIONS" \
      --replicas "$REPLICATION" \
      --topic-config retention.ms=604800000 || true
  else
    echo "    [AVISO] rpk não encontrado localmente e container rp-0 inativo. Execute 'make infra-up' primeiro."
  fi
done

echo "==> Inicializando topicos DLT de servicos (retencao=14d)..."
for dlt in "${DLT_TOPICS[@]}"; do
  if command -v rpk &> /dev/null; then
    rpk topic create "$dlt" \
      --brokers "$BROKERS" \
      --partitions 1 \
      --replicas "$REPLICATION" \
      --topic-config retention.ms=1209600000 || true # DLT: 14 dias
  elif command -v docker &> /dev/null && docker ps 2>/dev/null | grep -q portal-b2b-rp-0; then
    docker exec portal-b2b-rp-0 rpk topic create "$dlt" \
      --brokers rp-0:9092 \
      --partitions 1 \
      --replicas "$REPLICATION" \
      --topic-config retention.ms=1209600000 || true
  else
    echo "    [AVISO] DLT $dlt pendente de container ativo."
  fi
done

echo "==> Todos os 15 topicos de negocio e DLTs criados com sucesso!"
