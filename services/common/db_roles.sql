-- ==============================================================================
-- Script de Criação de Schemas, Roles Segregadas e Permissões - RFI-09.1 a RFI-09.3
-- ==============================================================================

-- 1. Criação das Roles Administrativas e de DDL
DO $$
BEGIN
  -- Role de Administração Global (RFI-09.1: não usada por microsserviços)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portal_admin') THEN
    CREATE ROLE portal_admin WITH LOGIN PASSWORD 'AdminMasterPass2026!#' SUPERUSER;
  END IF;

  -- Role Exclusiva para Execução de Migrações/DDL (RFI-09.2)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portal_ddl') THEN
    CREATE ROLE portal_ddl WITH LOGIN PASSWORD 'DDLMigrationsPass2026!#';
  END IF;

  -- Roles DML Específicas por Microsserviço (RFI-09.3)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_usuarios') THEN
    CREATE ROLE svc_usuarios WITH LOGIN PASSWORD 'SvcUsuariosPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_produtos') THEN
    CREATE ROLE svc_produtos WITH LOGIN PASSWORD 'SvcProdutosPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_fornecimentos') THEN
    CREATE ROLE svc_fornecimentos WITH LOGIN PASSWORD 'SvcFornecimentosPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_demanda') THEN
    CREATE ROLE svc_demanda WITH LOGIN PASSWORD 'SvcDemandaPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_mercado') THEN
    CREATE ROLE svc_mercado WITH LOGIN PASSWORD 'SvcMercadoPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_negociacao') THEN
    CREATE ROLE svc_negociacao WITH LOGIN PASSWORD 'SvcNegociacaoPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_pedidos') THEN
    CREATE ROLE svc_pedidos WITH LOGIN PASSWORD 'SvcPedidosPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_logistica') THEN
    CREATE ROLE svc_logistica WITH LOGIN PASSWORD 'SvcLogisticaPass2026!#';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'svc_transportadoras') THEN
    CREATE ROLE svc_transportadoras WITH LOGIN PASSWORD 'SvcTransportadorasPass2026!#';
  END IF;
END $$;

-- 2. Criação dos 9 Schemas Isolados pertencentes à role portal_ddl
CREATE SCHEMA IF NOT EXISTS usuarios AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS produtos AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS fornecimentos AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS demanda AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS mercado AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS negociacao AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS pedidos AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS logistica AUTHORIZATION portal_ddl;
CREATE SCHEMA IF NOT EXISTS transportadoras AUTHORIZATION portal_ddl;

-- 3. Revogação de privilégios públicos para garantia de menor privilégio
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE portal_b2b FROM PUBLIC;

GRANT CONNECT ON DATABASE portal_b2b TO portal_ddl;
GRANT CONNECT ON DATABASE portal_b2b TO svc_usuarios, svc_produtos, svc_fornecimentos, svc_demanda,
  svc_mercado, svc_negociacao, svc_pedidos, svc_logistica, svc_transportadoras;

-- 4. Associação de Permissões Estritas: Cada serviço acessa APENAS seu schema (RFI-09.3)
GRANT USAGE ON SCHEMA usuarios TO svc_usuarios;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA usuarios TO svc_usuarios;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA usuarios TO svc_usuarios;

GRANT USAGE ON SCHEMA produtos TO svc_produtos;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA produtos TO svc_produtos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA produtos TO svc_produtos;

GRANT USAGE ON SCHEMA fornecimentos TO svc_fornecimentos;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA fornecimentos TO svc_fornecimentos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA fornecimentos TO svc_fornecimentos;

GRANT USAGE ON SCHEMA demanda TO svc_demanda;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA demanda TO svc_demanda;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA demanda TO svc_demanda;

GRANT USAGE ON SCHEMA mercado TO svc_mercado;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA mercado TO svc_mercado;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA mercado TO svc_mercado;

GRANT USAGE ON SCHEMA negociacao TO svc_negociacao;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA negociacao TO svc_negociacao;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA negociacao TO svc_negociacao;

GRANT USAGE ON SCHEMA pedidos TO svc_pedidos;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pedidos TO svc_pedidos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pedidos TO svc_pedidos;

GRANT USAGE ON SCHEMA logistica TO svc_logistica;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA logistica TO svc_logistica;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA logistica TO svc_logistica;

GRANT USAGE ON SCHEMA transportadoras TO svc_transportadoras;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA transportadoras TO svc_transportadoras;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA transportadoras TO svc_transportadoras;

-- 5. Estrutura de Tabelas (Seção 10.2) executada por portal_ddl
SET ROLE portal_ddl;

-- Schema usuarios
CREATE TABLE IF NOT EXISTS usuarios.empresa (
  id VARCHAR(64) PRIMARY KEY,
  cnpj VARCHAR(32) UNIQUE NOT NULL,
  razao_social VARCHAR(255) NOT NULL,
  tipo VARCHAR(32) NOT NULL, -- compradora, fornecedora, transportadora
  ativo BOOLEAN DEFAULT TRUE,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS usuarios.usuario (
  id VARCHAR(64) PRIMARY KEY,
  empresa_id VARCHAR(64) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  senha_hash VARCHAR(255) NOT NULL,
  perfil VARCHAR(32) NOT NULL, -- comprador, fornecedor, transportadora, admin
  ativo BOOLEAN DEFAULT TRUE,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS usuarios.audit_log (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  acao VARCHAR(64) NOT NULL,
  usuario_id VARCHAR(64),
  correlation_id VARCHAR(64),
  detalhes JSONB
);

CREATE TABLE IF NOT EXISTS usuarios.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema produtos
CREATE TABLE IF NOT EXISTS produtos.produto (
  id VARCHAR(64) PRIMARY KEY,
  nome VARCHAR(255) NOT NULL,
  categoria VARCHAR(64) NOT NULL,
  unidade VARCHAR(32) NOT NULL,
  tipo_transporte VARCHAR(64) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS produtos.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema fornecimentos
CREATE TABLE IF NOT EXISTS fornecimentos.fornecimento (
  id VARCHAR(64) PRIMARY KEY,
  fornecedor_id VARCHAR(64) NOT NULL,
  produto_id VARCHAR(64) NOT NULL,
  preco NUMERIC(12, 2) NOT NULL,
  quantidade_disponivel NUMERIC(12, 2) NOT NULL,
  origem VARCHAR(255) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fornecimentos.movimento_estoque (
  id SERIAL PRIMARY KEY,
  fornecimento_id VARCHAR(64) NOT NULL,
  quantidade_alterada NUMERIC(12, 2) NOT NULL,
  motivo VARCHAR(64) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fornecimentos.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema demanda
CREATE TABLE IF NOT EXISTS demanda.demanda (
  id VARCHAR(64) PRIMARY KEY,
  comprador_id VARCHAR(64) NOT NULL,
  produto_id VARCHAR(64) NOT NULL,
  quantidade NUMERIC(12, 2) NOT NULL,
  preco_teto NUMERIC(12, 2),
  tipo VARCHAR(32) NOT NULL, -- PONTUAL ou RECORRENTE
  frequencia_segundos INT DEFAULT 0,
  proxima_execucao TIMESTAMP WITH TIME ZONE,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS demanda.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema mercado
CREATE TABLE IF NOT EXISTS mercado.match (
  id VARCHAR(64) PRIMARY KEY,
  demanda_id VARCHAR(64) NOT NULL,
  fornecimento_id VARCHAR(64) NOT NULL,
  status VARCHAR(32) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mercado.modo_negociacao (
  id VARCHAR(64) PRIMARY KEY,
  match_id VARCHAR(64) NOT NULL,
  modo VARCHAR(32) NOT NULL, -- VENDA_DIRETA, LEILAO_DIRETO, LEILAO_REVERSO
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mercado.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema negociacao
CREATE TABLE IF NOT EXISTS negociacao.negociacao (
  id VARCHAR(64) PRIMARY KEY,
  modo VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL, -- ABERTA, FECHADA, CANCELADA
  vencedor_id VARCHAR(64),
  valor_final NUMERIC(12, 2),
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS negociacao.lance (
  id VARCHAR(64) PRIMARY KEY,
  negociacao_id VARCHAR(64) NOT NULL,
  empresa_id VARCHAR(64) NOT NULL,
  valor NUMERIC(12, 2) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS negociacao.idempotency_keys (
  key VARCHAR(128) PRIMARY KEY,
  response_payload JSONB NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS negociacao.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema pedidos
CREATE TABLE IF NOT EXISTS pedidos.pedido (
  id VARCHAR(64) PRIMARY KEY,
  negociacao_id VARCHAR(64) UNIQUE NOT NULL, -- RF-09: 1 pedido por negociacaoId
  status VARCHAR(32) NOT NULL, -- CRIADO, AGUARDANDO_FRETE, FRETE_SELECIONADO, ENTREGUE, CANCELADO
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pedidos.pedido_historico (
  id SERIAL PRIMARY KEY,
  pedido_id VARCHAR(64) NOT NULL,
  status_anterior VARCHAR(32),
  status_novo VARCHAR(32) NOT NULL,
  data_transicao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pedidos.idempotency_keys (
  key VARCHAR(128) PRIMARY KEY,
  response_payload JSONB NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pedidos.audit_log (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  acao VARCHAR(64) NOT NULL,
  usuario_id VARCHAR(64),
  correlation_id VARCHAR(64),
  detalhes JSONB
);

CREATE TABLE IF NOT EXISTS pedidos.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema logistica
CREATE TABLE IF NOT EXISTS logistica.solicitacao_frete (
  id VARCHAR(64) PRIMARY KEY,
  pedido_id VARCHAR(64) NOT NULL,
  status VARCHAR(32) NOT NULL, -- ABERTA, COTADA, SELECIONADA
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS logistica.cotacao (
  id VARCHAR(64) PRIMARY KEY,
  solicitacao_id VARCHAR(64) NOT NULL,
  transportadora_id VARCHAR(64) NOT NULL,
  preco NUMERIC(12, 2) NOT NULL,
  prazo_dias INT NOT NULL,
  selecionada BOOLEAN DEFAULT FALSE,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS logistica.idempotency_keys (
  key VARCHAR(128) PRIMARY KEY,
  response_payload JSONB NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS logistica.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Schema transportadoras
CREATE TABLE IF NOT EXISTS transportadoras.transportadora (
  id VARCHAR(64) PRIMARY KEY,
  empresa_id VARCHAR(64) NOT NULL,
  criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transportadoras.regra_cotacao (
  id VARCHAR(64) PRIMARY KEY,
  transportadora_id VARCHAR(64) NOT NULL,
  preco_base NUMERIC(12, 2) NOT NULL,
  prazo_dias INT NOT NULL
);

CREATE TABLE IF NOT EXISTS transportadoras.processed_events (
  event_id VARCHAR(64) PRIMARY KEY,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

RESET ROLE;
