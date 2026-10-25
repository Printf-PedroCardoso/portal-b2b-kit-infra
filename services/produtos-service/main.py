import sys
import os
import uuid
from typing import List, Optional
from fastapi import FastAPI, Request, Response, status, Query
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event

SERVICE_NAME = "produtos-service"
PORT = 8102

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Produtos API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_produtos = {}

class ProdutoCreate(BaseModel):
    nome: str = Field(..., min_length=2)
    categoria: str = Field(..., min_length=2)
    unidade: str = Field(..., description="KG, TON, UN, CX, L")
    tipo_transporte: str = Field(..., description="GRANEL, REFRIGERADO, CARGA_SECA, PERIGOSO")

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 33\n",
        media_type="text/plain"
    )

@app.post("/api/v1/produtos", status_code=status.HTTP_201_CREATED)
async def cadastrar_produto(dto: ProdutoCreate):
    # RF-03: Cadastrar catálogo de produtos e publicar evento produto_cadastrado
    produto_id = str(uuid.uuid4())
    produto_record = {
        "id": produto_id,
        "nome": dto.nome,
        "categoria": dto.categoria,
        "unidade": dto.unidade,
        "tipo_transporte": dto.tipo_transporte
    }
    db_produtos[produto_id] = produto_record

    await publish_event(
        event_type="produto_cadastrado",
        source=SERVICE_NAME,
        aggregate_id=produto_id,
        payload=produto_record
    )

    return produto_record

@app.get("/api/v1/produtos")
async def listar_produtos(
    categoria: Optional[str] = Query(None, description="Filtro opcional por categoria (RF-03)"),
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100)
):
    itens = list(db_produtos.values())
    if categoria:
        # RF-03: GET ?categoria=X retorna só a categoria X
        itens = [p for p in itens if p.get("categoria") == categoria]

    start = (page - 1) * size
    return itens[start:start + size]

@app.get("/api/v1/produtos/{produto_id}")
async def obter_produto(produto_id: str):
    if produto_id not in db_produtos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Produto não cadastrado.")
    return db_produtos[produto_id]
