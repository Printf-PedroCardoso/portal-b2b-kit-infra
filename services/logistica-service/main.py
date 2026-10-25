import sys
import os
import uuid
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Request, Response, status, Header, Query
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event
from common.audit import record_audit
from common.idempotency import get_idempotent_response, save_idempotent_response

SERVICE_NAME = "logistica-service"
PORT = 8108

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Logística e Frete API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_solicitacoes = {}
db_cotacoes = {}

class SolicitacaoFreteCreate(BaseModel):
    pedido_id: str

class CotacaoCreate(BaseModel):
    solicitacao_id: str
    transportadora_id: str
    preco: float = Field(..., gt=0)
    prazo_dias: int = Field(..., gt=0)

class SelecaoFreteRequest(BaseModel):
    cotacao_id: Optional[str] = None

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 44\n",
        media_type="text/plain"
    )

@app.post("/api/v1/logistica/solicitacoes", status_code=status.HTTP_201_CREATED)
async def criar_solicitacao_frete(dto: SolicitacaoFreteCreate):
    # RF-11.1: Dado pedido_criado, registra a solicitacao e publica solicitacao_frete_criada
    solicitacao_id = str(uuid.uuid4())
    record = {
        "id": solicitacao_id,
        "pedido_id": dto.pedido_id,
        "status": "ABERTA",
        "cotacoes": []
    }
    db_solicitacoes[solicitacao_id] = record

    # RF-11.1: Publica solicitacao_frete_criada
    await publish_event(
        event_type="solicitacao_frete_criada",
        source=SERVICE_NAME,
        aggregate_id=solicitacao_id,
        payload={
            "solicitacaoFreteId": solicitacao_id,
            "pedidoId": dto.pedido_id,
            "status": "ABERTA"
        }
    )

    return record

@app.get("/api/v1/logistica/solicitacoes")
async def listar_solicitacoes():
    return list(db_solicitacoes.values())

@app.get("/api/v1/logistica/solicitacoes/{id}")
async def obter_solicitacao(id: str):
    if id not in db_solicitacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Solicitação inexistente.")
    return db_solicitacoes[id]

@app.post("/api/v1/logistica/cotacoes", status_code=status.HTTP_201_CREATED)
async def registrar_cotacao(dto: CotacaoCreate):
    if dto.solicitacao_id not in db_solicitacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Solicitação de frete inexistente.")

    cotacao_id = str(uuid.uuid4())
    cotacao_record = {
        "id": cotacao_id,
        "solicitacao_id": dto.solicitacao_id,
        "transportadora_id": dto.transportadora_id,
        "preco": dto.preco,
        "prazo_dias": dto.prazo_dias,
        "selecionada": False
    }
    db_cotacoes[cotacao_id] = cotacao_record
    db_solicitacoes[dto.solicitacao_id]["cotacoes"].append(cotacao_record)

    return cotacao_record

@app.post("/api/v1/logistica/solicitacoes/{id}/selecionar-frete")
async def selecionar_frete(
    id: str,
    dto: Optional[SelecaoFreteRequest] = None,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key")
):
    # CT-A06: Idempotência na seleção de frete
    if idempotency_key:
        cached = get_idempotent_response(idempotency_key)
        if cached:
            return cached

    if id not in db_solicitacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Solicitação inexistente.")

    solicitacao = db_solicitacoes[id]
    cotacoes = solicitacao.get("cotacoes", [])

    if len(cotacoes) < 2 and not dto.cotacao_id:
        raise ProblemException(
            status_code=422,
            title="Cotações Insuficientes",
            detail="São necessárias pelo menos 2 cotações para seleção comparativa (RF-12)."
        )

    # RF-12: Regra padrão: menor preço, desempate por menor prazo
    if dto and dto.cotacao_id:
        escolhida = next((c for c in cotacoes if c["id"] == dto.cotacao_id), None)
        if not escolhida:
            raise ProblemException(status_code=404, title="Não Encontrado", detail="Cotação indicada não pertence a esta solicitação.")
    else:
        # Ordenação: preco asc, prazo_dias asc (RF-12)
        cotacoes_ordenadas = sorted(cotacoes, key=lambda c: (c["preco"], c["prazo_dias"]))
        escolhida = cotacoes_ordenadas[0]

    # Exatamente 1 cotação fica 'selecionada'
    for c in cotacoes:
        c["selecionada"] = (c["id"] == escolhida["id"])

    solicitacao["status"] = "SELECIONADA"
    solicitacao["cotacao_selecionada"] = escolhida

    payload_evento = {
        "pedidoId": solicitacao["pedido_id"],
        "solicitacaoFreteId": id,
        "cotacaoId": escolhida["id"],
        "transportadoraId": escolhida["transportadora_id"],
        "preco": escolhida["preco"],
        "prazoDias": escolhida["prazo_dias"],
        "status": "FRETE_SELECIONADO"
    }

    # RF-12: frete_selecionado é publicado e pedido vai a FRETE_SELECIONADO
    await publish_event(
        event_type="frete_selecionado",
        source=SERVICE_NAME,
        aggregate_id=solicitacao["pedido_id"],
        payload=payload_evento
    )

    record_audit(SERVICE_NAME, "SELECIONAR_FRETE", "system", solicitacao["pedido_id"], payload_evento)

    response_data = {
        "status": "FRETE_SELECIONADO",
        "pedido_id": solicitacao["pedido_id"],
        "cotacao_vencedora": escolhida
    }

    if idempotency_key:
        save_idempotent_response(idempotency_key, 200, response_data)

    return response_data
