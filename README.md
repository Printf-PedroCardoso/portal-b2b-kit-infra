# KIT DE INTEGRAÇÃO DA INFRAESTRUTURA — PORTAL B2B DISTRIBUÍDO
**Ambiente Local, Boilerplates de Microsserviços e Contratos de Integração**  
**Emissor:** Equipe de Infraestrutura e DevOps (Pedro Cardoso, Antoniel Brito, Flaelisnanda Dacio)  
**Disciplina:** Sistemas Distribuídos — 2026  

---

## 1. O que é este Kit?

Este repositório contém toda a **fundação compartilhada de infraestrutura local** preparada pela Equipe de Infraestrutura para todos os 9 grupos de trabalho do projeto integrado do **Portal B2B Distribuído**.

### O que já está pronto para uso:
- **Banco de Dados Relacional:** PostgreSQL 16 com o banco `portal_b2b`, particionado em **9 schemas estanques** e roles `svc_*` com permissões DML de privilégio mínimo.
- **Barramento de Mensageria:** Cluster **Redpanda de 3 brokers** (compatível 100% com a API Apache Kafka) na porta `19092`, com os **15 tópicos oficiais de negócio** pré-configurados.
- **Ponto Único de Borda:** **Gateway Nginx** na porta `8080` (HTTP) e `8443` (HTTPS com TLS), roteando tráfego para APIs (`/api/v1/*`) e interfaces web, com controle de vazão (*rate limiting*) e injeção do cabeçalho `X-Correlation-Id`.
- **Painéis Administrativos Visuais:**
  - **PgAdmin 4** (Web UI do PostgreSQL) na porta `5050`;
  - **Kafka UI** (Web UI do cluster Redpanda) na porta `8090`.
- **Esqueletos dos Microsserviços (Boilerplates):** 9 projetos base em FastAPI já configurados com Dockerfile multi-stage, endpoints de vitalidade (`/health`), métricas Prometheus (`/metrics`), Swagger interativo (`/docs`) e tratamento padronizado de erros **RFC 7807**.

---

## 2. Estrutura do Repositório

```text
kit-integracao-infraestrutura/
├── database/
│   └── 01-init.sql                 # Script de criação dos 9 schemas e roles no PostgreSQL
├── gateway/
│   ├── Dockerfile                  # Imagem Alpine do Nginx Gateway
│   ├── nginx.conf                  # Configurações de rate limiting, TLS e proxy reverso
│   ├── common_routes.conf          # Regras de roteamento para as portas 8101 a 8109
│   └── certs/                      # Certificados SSL autoassinados para desenvolvimento
├── frontends/                      # Interfaces estáticas dos 7 domínios do portal
├── observabilidade/                # Configurações de Prometheus, Grafana, Loki e Alertmanager
├── scripts/
│   └── init_topics.sh              # Script de provisionamento dos 15 tópicos no Redpanda
├── services/
│   ├── common/                     # Módulos Python reutilizáveis (logger JSON, RFC 7807, auth, events)
│   │   └── CONTRACTS.md            # Catálogo oficial dos 15 eventos e seus envelopes JSON
│   ├── usuarios-service/           # Esqueleto da API de Autenticação, Usuários e Empresas (:8101)
│   ├── produtos-service/           # Esqueleto da API de Catálogo de Produtos (:8102)
│   ├── fornecimentos-service/      # Esqueleto da API de Fornecimento e Estoque (:8103)
│   ├── demanda-service/            # Esqueleto da API de Demandas de Compra (:8104)
│   ├── mercado-service/            # Esqueleto da API de Mercado e Matching Engine (:8105)
│   ├── negociacao-service/         # Esqueleto da API de Negociações e Leilões (:8106)
│   ├── pedidos-service/            # Esqueleto da API de Pedidos de Compra (:8107)
│   ├── logistica-service/          # Esqueleto da API de Gestão Logística (:8108)
│   └── transportadoras-service/    # Esqueleto da API de Transportadoras Homologadas (:8109)
├── .env.example                    # Modelo de variáveis de ambiente padrão
├── docker-compose.yml              # Orquestrador da stack completa em containers
├── Makefile                        # Comandos facilitadores para o terminal
├── CONTRACTS.md                    # Cópia direta do catálogo de contratos de eventos
├── ORIENTACOES-ARQUITETURA-GRUPOS.md# GUIA COMPLETO de diretrizes por equipe
└── README.md                       # Este manual de início rápido
```

---

## 3. Guia Rápido: Como Subir a Infraestrutura em 3 Passos

### Pré-requisitos:
- Ter o **Docker** e o **Docker Compose** instalados na sua máquina.

### Passo 1: Clonar o Repositório e Configurar o `.env`
No seu terminal, clone este repositório e execute:
```bash
# Copia as variáveis padrão para o arquivo .env
make env
# (Ou no Windows / terminal simples: cp .env.example .env)
```

### Passo 2: Inicializar a Infraestrutura Base Compartilhada
Recomendamos inicializar a **infraestrutura base** (Banco, Redpanda, Gateway e Painéis):
```bash
make infra-up
```
*Se preferir usar o comando direto do Docker:*
```bash
docker compose up -d pg-primary rp-0 rp-1 rp-2 gateway pgadmin kafka-ui frontends
# Em seguida, crie os tópicos de mensagens:
bash ./scripts/init_topics.sh
```

### Passo 3: Acessar os Painéis no seu Navegador
Após a inicialização, abra no seu navegador:

| Serviço | URL de Acesso Local | Credenciais Padrão (.env) |
|---|---|---|
| **Gateway Oficial (Borda)** | `http://localhost:8080` ou `https://localhost:8443` | — (Acesso direto a APIs e Front-ends) |
| **Kafka UI (Mensageria Redpanda)** | `http://localhost:8090` | Acesso livre (monitora os 15 tópicos em tempo real) |
| **PgAdmin 4 (Web UI do PostgreSQL)**| `http://localhost:5050` | **Login:** `admin@portalb2b.local`<br>**Senha:** `AdminPgLocal123!#` |
| **PostgreSQL Direto (DBeaver / DataGrip)** | `localhost:5432` | **Banco:** `portal_b2b`<br>**User:** `portal_admin`<br>**Senha:** `AdminMasterPass2026!#` |

> [!TIP]
> **Adicionando o PostgreSQL no PgAdmin:**  
> No PgAdmin, clique com o botão direito em *Servers* $\rightarrow$ *Register* $\rightarrow$ *Server*. Na aba *Connection*, coloque:
> - **Host name/address:** `pg-primary`
> - **Port:** `5432`
> - **Maintenance database:** `portal_b2b`
> - **Username:** `portal_admin` (ou a role do seu serviço, ex: `svc_demanda`)
> - **Password:** `AdminMasterPass2026!#` (ou a senha do seu serviço definida no `database/01-init.sql`)

---

## 4. Como Desenvolver o Microsserviço do seu Grupo

Cada equipe de desenvolvimento pode escolher a forma mais produtiva de trabalhar:

### Modo A — Desenvolvimento Local Ágil (Recomendado)
Neste modo, você roda a infraestrutura compartilhada (Postgres + Redpanda + Gateway) no Docker, mas roda o código da sua API **diretamente no terminal da sua máquina (com hot-reload)**:

1. Suba a infra base: `make infra-up`.
2. Entre na pasta do serviço do seu grupo (exemplo: `services/demanda-service`):
   ```bash
   cd services/demanda-service
   ```
3. Crie e ative um ambiente virtual Python:
   ```bash
   python -m venv venv
   source venv/bin/activate  # No Windows: .\venv\Scripts\activate
   pip install -r requirements.txt
   ```
4. Execute sua API em modo de desenvolvimento na sua porta oficial (veja a tabela abaixo):
   ```bash
   uvicorn main:app --reload --port 8104
   ```
5. Acesse a documentação interativa da sua API em: `http://localhost:8104/docs` ou via Gateway em `http://localhost:8080/api/v1/demandas`.

---

### Modo B — Execução da Stack Completa em Contêineres
Se você quiser ver todos os 9 microsserviços simulados rodando simultaneamente dentro do Docker Compose:
```bash
make up
# (Ou: docker compose up -d)
```
Para parar e limpar:
```bash
make down
# (Ou: docker compose down -v)
```

---

## 5. Tabela Rápida de Atribuições, Portas e Schemas

| Grupo de Trabalho | Serviço Atribuído | Porta Oficial | Schema no PostgreSQL | Usuário de Conexão DML | Senha Padrão |
|---|---|:---:|:---:|:---:|:---:|
| **Autenticação (Equipe A)** | `usuarios-service` | `8101` | `usuarios` | `svc_usuarios` | `SvcUsuariosPass2026!#` |
| **Fornecimento e Produtos** | `produtos-service`<br>`fornecimentos-service` | `8102`<br>`8103` | `produtos`<br>`fornecimentos` | `svc_produtos`<br>`svc_fornecimentos` | `SvcProdutosPass2026!#`<br>`SvcFornecimentosPass2026!#` |
| **Compra e Demanda** | `demanda-service` | `8104` | `demanda` | `svc_demanda` | `SvcDemandaPass2026!#` |
| **Mercado, Negociação e Pedidos** | `mercado-service`<br>`negociacao-service`<br>`pedidos-service` | `8105`<br>`8106`<br>`8107` | `mercado`<br>`negociacao`<br>`pedidos` | `svc_mercado`<br>`svc_negociacao`<br>`svc_pedidos` | `SvcMercadoPass2026!#`<br>`SvcNegociacaoPass2026!#`<br>`SvcPedidosPass2026!#` |
| **Logística e Transporte** | `logistica-service`<br>`transportadoras-service` | `8108`<br>`8109` | `logistica`<br>`transportadoras` | `svc_logistica`<br>`svc_transportadoras` | `SvcLogisticaPass2026!#`<br>`SvcTransportadorasPass2026!#` |
| **Banco de Dados** | Todos os Schemas | `5432` | Todos (9 schemas) | `portal_ddl` (migrações)<br>`portal_admin` (admin) | `DDLMigrationsPass2026!#`<br>`AdminMasterPass2026!#` |
| **UX / UI** | 7 Front-ends | `8080` (GW) | — | — | — |
| **Teste e Qualidade** | Suíte de Auditoria | — | — | — | — |

---

## 6. As 5 Regras Inegociáveis de Integração

Para garantir que o trabalho de uma equipe não quebre o das outras:

1. **Prefixo de Rota:** Todas as rotas de negócio devem começar com `/api/v1/<servico>`.
2. **Endpoints Obrigatórios:** Toda API deve implementar `/health`, `/health/ready`, `/metrics` e `/docs`.
3. **Erros Padronizados (RFC 7807):** Respostas de erro devem ser JSON com cabeçalho `application/problem+json` contendo `type`, `title`, `status`, `detail` e `correlationId` (utilize o módulo `common/errors.py` já pronto).
4. **Isolamento de Banco:** Nunca faça consultas ou joins em schemas alheios. Se precisar de dados de outro serviço, consuma eventos do Redpanda.
5. **Pool de Conexões:** Configure seu pool de banco para no **máximo 5 conexões ativas**.

---

## 7. Documentação Completa e Detalhada

- Para ler o manual completo de arquitetura com detalhes de BDD, fluxos de negócio, regras de RBAC e LGPD, leia o arquivo [**`ORIENTACOES-ARQUITETURA-GRUPOS.md`**](ORIENTACOES-ARQUITETURA-GRUPOS.md).
- Para consultar o catálogo dos 15 tópicos e os exemplos de payloads JSON de cada evento, leia o arquivo [**`CONTRACTS.md`**](CONTRACTS.md).

---

## 8. Suporte da Equipe de Infraestrutura

Qualquer problema de rede, portas em conflito, permissões de banco ou dúvidas sobre o Redpanda, entre em contato com a **Equipe de Infraestrutura**:
- **Pedro Cardoso da Mata**
- **Antoniel Brito Andrade**
- **Flaelisnanda Oliveira dos Santos Dacio**

*Bom desenvolvimento a todos os grupos!*
