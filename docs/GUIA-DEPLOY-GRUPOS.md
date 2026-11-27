# Guia Rápido de Deploy na AWS — Equipes de Microsserviços

Este guia explica como colocar seu microsserviço no ar no ambiente de **Integração (AWS)** sem precisar instalar AWS CLI nem acessar os servidores manualmente.

O deploy é 100% automático via **GitHub Actions**: ao dar `git push` na branch `main` do repositório do seu serviço, a imagem Docker é construída, enviada ao Amazon ECR e atualizada automaticamente nas duas máquinas (`app1` e `app2`).

---

## 1. Requisitos Obrigatórios no Repositório do seu Serviço

Antes de ativar o deploy, garanta que o seu repositório atende aos 4 pontos abaixo:

1. **`Dockerfile` na raiz do repositório** que suba a aplicação escutando em `0.0.0.0` na porta oficial do seu serviço:
   | Serviço (`SERVICE_NAME`) | Porta | Prefixos no Gateway |
   |---|:---:|---|
   | `usuarios-service` | `8101` | `/api/v1/auth/`, `/api/v1/tenants`, `/api/v1/users/`, `/api/v1/usuarios`, `/.well-known/jwks.json` |
   | `produtos-service` | `8102` | `/api/v1/produtos` |
   | `fornecimentos-service` | `8103` | `/api/v1/fornecimentos` |
   | `demanda-service` | `8104` | `/api/v1/demandas` |
   | `mercado-service` | `8105` | `/api/v1/mercado` |
   | `negociacao-service` | `8106` | `/api/v1/negociacoes` |
   | `pedidos-service` | `8107` | `/api/v1/pedidos` |
   | `logistica-service` | `8108` | `/api/v1/logistica` |
   | `transportadoras-service` | `8109` | `/api/v1/transportadoras` |

2. **Ler configurações por variáveis de ambiente** (nunca deixar `localhost` fixo no código). A infraestrutura injeta automaticamente no seu container:
   - Banco de Dados: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA` e `DATABASE_URL`
   - Mensageria: `KAFKA_BOOTSTRAP_SERVERS`, `SCHEMA_REGISTRY_URL`
   - Redis: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
   - Autenticação: `JWT_SECRET_KEY`, `JWT_ALGORITHM`
   - Serviço: `SERVICE_NAME`, `PORT`, `ENVIRONMENT`

3. **Endpoints de saúde obrigatórios:**
   - `GET /health` → retorna HTTP `200`
   - `GET /health/ready` → retorna HTTP `200` quando banco e Kafka estiverem acessíveis

4. **Testar o build Docker localmente antes do push:**
   ```bash
   docker build -t meu-servico:teste .
   ```

---

## 2. Como Ativar o Deploy Automático (Passo Único)

1. Copie o arquivo modelo [`docs/templates/deploy-microservico.yml`](templates/deploy-microservico.yml) para o caminho **`.github/workflows/deploy.yml`** no repositório do seu microsserviço.
2. Abra `.github/workflows/deploy.yml` e altere **apenas a linha `SERVICE_NAME`** para o nome exato do seu serviço (conforme a tabela acima):
   ```yaml
   env:
     SERVICE_NAME: produtos-service # <-- troque pelo seu
   ```
3. Confirme com a Equipe de Infraestrutura que os Secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` já estão configurados no seu repositório (ou na Organização do GitHub).
4. Faça `git push` para a branch `main` (ou clique em **Actions → Deploy Microsservico → Run workflow**).

---

## 3. Como Acompanhar e Ver Logs

1. Acesse a aba **Actions** do seu repositório no GitHub e abra a execução mais recente.
2. No passo **"Disparar deploy em app1 e app2 via AWS SSM"**, o workflow exibe:
   - Status do container em `app1` e `app2`
   - As **últimas 40 linhas de log** da sua aplicação ao subir
3. Se o container der erro na inicialização, o workflow falha automaticamente e mostra o traceback direto no log do GitHub Actions.
4. Assim que ficar verde, teste sua API usando o endereço do **ALB** fornecido pela Equipe de Infraestrutura (ex: `http://<ALB_DNS>/api/v1/produtos/...`).
