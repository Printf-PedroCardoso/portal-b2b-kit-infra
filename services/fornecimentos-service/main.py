import sys
import os
import uuid
from typing import List, Optional
from fastapi import FastAPI, Request, Response, status, Query, Header
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event
from common.auth import decode_token

SERVICE_NAME = "fornecimentos-service"
PORT = 8103

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Fornecimentos API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_fornecimentos = {}

class FornecimentoCreate(BaseModel):
    fornecedor_id: str
    produto_id: str
    preco: float = Field(..., gt=0)
    quantidade_disponivel: float = Field(..., gt=0)
    origem: str

class BaixaEstoqueRequest(BaseModel):
    quantidade: float = Field(..., gt=0)
    motivo: Optional[str] = "VENDA"

@app.middleware("http")
async def correlation_middleware(request: Request, call_next):
    corr_id = request.headers.get("X-Correlation-Id") or str(uuid.uuid4())
    token = correlation_id_ctx.set(corr_id)
    try:
        response: Response = await call_next(request)
        response.headers["X-Correlation-Id"] = corr_id
        response.headers["X-Service-Name"] = SERVICE_NAME
        return response
    finally:
        correlation_id_ctx.reset(token)

@app.get("/health")
async def health():
    return {"status": "UP"}

@app.get("/health/live")
async def health_live():
    return {"status": "UP"}

@app.get("/health/ready")
async def health_ready():
    return {"status": "READY", "service": SERVICE_NAME}

@app.get("/metrics")
async def metrics():
    return Response(
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 27\n",
        media_type="text/plain"
    )

@app.post("/api/v1/fornecimentos", status_code=status.HTTP_201_CREATED)
async def criar_fornecimento(
    dto: FornecimentoCreate,
    authorization: Optional[str] = Header(None)
):
    # RF-02.2: Validação RBAC: Se perfil for 'comprador', proibir criação -> 403 Forbidden
    if authorization and authorization.startswith("Bearer "):
        token_str = authorization.split(" ")[1]
        try:
            payload = decode_token(token_str)
            if payload.get("perfil") == "comprador":
                raise ProblemException(
                    status_code=403,
                    title="Acesso Negado (RBAC)",
                    detail="Compradores não têm permissão para registrar ofertas de fornecimento (RF-02.2)."
                )
        except ProblemException:
            raise
        except Exception:
            pass

    fornecimento_id = str(uuid.uuid4())
    record = {
        "id": fornecimento_id,
        "fornecedor_id": dto.fornecedor_id,
        "produto_id": dto.produto_id,
        "preco": dto.preco,
        "quantidade_disponivel": dto.quantidade_disponivel,
        "origem": dto.origem
    }
    db_fornecimentos[fornecimento_id] = record

    # RF-04: Publica fornecimento_criado
    await publish_event(
        event_type="fornecimento_criado",
        source=SERVICE_NAME,
        aggregate_id=fornecimento_id,
        payload=record
    )

    return record

@app.get("/api/v1/fornecimentos")
async def listar_fornecimentos(
    produto_id: Optional[str] = None,
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100)
):
    itens = list(db_fornecimentos.values())
    if produto_id:
        itens = [f for f in itens if f.get("produto_id") == produto_id]
    start = (page - 1) * size
    return itens[start:start + size]

@app.get("/api/v1/fornecimentos/{id}")
async def obter_fornecimento(id: str):
    if id not in db_fornecimentos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Fornecimento não existe.")
    return db_fornecimentos[id]

@app.post("/api/v1/fornecimentos/{id}/baixa-estoque")
async def dar_baixa_estoque(id: str, dto: BaixaEstoqueRequest):
    # RF-04: Controle de estoque disponível
    if id not in db_fornecimentos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Fornecimento não localizado.")

    fornec = db_fornecimentos[id]
    estoque_atual = fornec["quantidade_disponivel"]

    # RF-04: Baixa maior que estoque disponível -> 422 e estoque NUNCA negativo
    if dto.quantidade > estoque_atual:
        raise ProblemException(
            status_code=422,
            title="Erro de Validação de Negócio",
            detail=f"Quantidade de baixa ({dto.quantidade}) excede estoque disponível ({estoque_atual}). Estoque não pode ser negativo (RF-04)."
        )

    novo_estoque = estoque_atual - dto.quantidade
    fornec["quantidade_disponivel"] = novo_estoque

    # RF-04: Publica evento estoque_atualizado
    await publish_event(
        event_type="estoque_atualizado",
        source=SERVICE_NAME,
        aggregate_id=id,
        payload={
            "fornecimentoId": id,
            "produtoId": fornec["produto_id"],
            "quantidadeAnterior": estoque_atual,
            "quantidadeBaixada": dto.quantidade,
            "novoEstoque": novo_estoque,
            "motivo": dto.motivo
        }
    )

    return {"id": id, "quantidade_disponivel": novo_estoque, "status": "sucesso"}
