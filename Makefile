# ==============================================================================
# Makefile — Kit de Integração da Infraestrutura (Portal B2B Distribuído)
# Facilitador de comandos para desenvolvimento local de todas as equipes
# ==============================================================================

.PHONY: help env infra-up infra-down up down ps logs clean init-topics

help:
	@echo "========================================================================"
	@echo "   KIT DE INTEGRAÇÃO DA INFRAESTRUTURA — COMANDOS RÁPIDOS"
	@echo "========================================================================"
	@echo "  make env           Copia .env.example para .env (primeiro passo)"
	@echo "  make infra-up      Sobe APENAS a infraestrutura base (Postgres, Redpanda, Gateway e UIs)"
	@echo "  make infra-down    Derruba a infraestrutura base"
	@echo "  make up            Sobe a infraestrutura E todos os 9 microsserviços simulados"
	@echo "  make down          Derruba todos os containers da stack"
	@echo "  make ps            Exibe o status dos containers"
	@echo "  make logs          Exibe os logs em tempo real (Ctrl+C para sair)"
	@echo "  make init-topics   Cria/Verifica os 15 tópicos oficiais no Redpanda"
	@echo "========================================================================"

env:
	@if [ ! -f .env ]; then \
		echo "--> Criando arquivo .env a partir de .env.example..."; \
		cp .env.example .env; \
		echo "--> Arquivo .env gerado com sucesso!"; \
	else \
		echo "--> Arquivo .env já existe."; \
	fi

infra-up: env
	@echo "==> Inicializando APENAS infraestrutura base (Postgres, Redpanda, Gateway, PgAdmin, Kafka UI)..."
	docker compose up -d pg-primary rp-0 rp-1 rp-2 gateway pgadmin kafka-ui frontends
	@echo "==> Aguardando estabilização dos serviços (10s)..."
	@sleep 10
	@bash ./scripts/init_topics.sh
	@echo "========================================================================"
	@echo "  INFRAESTRUTURA BASE PRONTA PARA USO!"
	@echo "  - Gateway (Borda):  http://localhost:8080"
	@echo "  - PostgreSQL 16:    localhost:5432 (Banco: portal_b2b)"
	@echo "  - PgAdmin:          http://localhost:5050 (login no .env)"
	@echo "  - Redpanda Kafka:   localhost:19092"
	@echo "  - Kafka UI:         http://localhost:8090"
	@echo "========================================================================"

infra-down:
	@echo "==> Encerrando serviços de infraestrutura..."
	docker compose stop pg-primary rp-0 rp-1 rp-2 gateway pgadmin kafka-ui frontends

up: env
	@echo "==> Inicializando toda a stack completa (Infraestrutura + 9 Microsserviços)..."
	docker compose up -d
	@echo "==> Aguardando estabilização dos serviços (15s)..."
	@sleep 15
	@bash ./scripts/init_topics.sh
	@echo "==> Stack completa no ar!"

down:
	@echo "==> Encerrando e removendo todos os containers..."
	docker compose down -v
	@echo "==> Stack finalizada."

ps:
	docker compose ps

logs:
	docker compose logs -f

init-topics:
	@bash ./scripts/init_topics.sh
