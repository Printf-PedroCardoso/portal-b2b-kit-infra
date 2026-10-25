import sys
import os
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Request, Response, status, Header, Query
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event
from common.audit import record_audit
from common.idempotency import get_idempotent_response, save_idempotent_response

SERVICE_NAME = "pedidos-service"
PORT = 8107

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Pedidos API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_pedidos = {}
db_negociacao_to_pedido = {} # Garantia de exatamente 1 pedido por negociacaoId (RF-09)
db_historico = {}

VALID_TRANSITIONS = {
    "CRIADO": ["AGUARDANDO_FRETE", "CANCELADO"],
    "AGUARDANDO_FRETE": ["FRETE_SELECIONADO", "CANCELADO"],
    "FRETE_SELECIONADO": ["ENTREGUE", "CANCELADO"],
    "ENTREGUE": [],
    "CANCELADO": []
}

class PedidoFromNegociacaoRequest(BaseModel):
    negociacao_id: str
    items: Optional[List[Dict[str, Any]]] = None

class StatusUpdateRequest(BaseModel):
    novo_status: str = Field(..., description="CRIADO, AGUARDANDO_FRETE, FRETE_SELECIONADO, ENTREGUE, CANCELADO")

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 61\n",
        media_type="text/plain"
    )

@app.post("/api/v1/pedidos", status_code=status.HTTP_201_CREATED)
async def criar_pedido_negociacao(
    dto: PedidoFromNegociacaoRequest,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key")
):
    # CT-A06: Idempotência
    if idempotency_key:
        cached = get_idempotent_response(idempotency_key)
        if cached:
            return cached

    # RF-09: Dado negociacao_fechada, existe exatamente 1 pedido por negociacaoId,
    # mesmo com evento reentregue.
    if dto.negociacao_id in db_negociacao_to_pedido:
        pedido_existente_id = db_negociacao_to_pedido[dto.negociacao_id]
        logger.info(f"Reentrega de negociacao_fechada detectada. Retornando pedido existente {pedido_existente_id} (RF-09).")
        return db_pedidos[pedido_existente_id]

    pedido_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    record = {
        "id": pedido_id,
        "negociacao_id": dto.negociacao_id,
        "status": "CRIADO",
        "criado_em": now
    }
    db_pedidos[pedido_id] = record
    db_negociacao_to_pedido[dto.negociacao_id] = pedido_id
    db_historico[pedido_id] = [
        {"status_anterior": None, "status_novo": "CRIADO", "data_transicao": now}
    ]

    # RF-09: Publica pedido_criado
    await publish_event(
        event_type="pedido_criado",
        source=SERVICE_NAME,
        aggregate_id=pedido_id,
        payload=record
    )

    record_audit(SERVICE_NAME, "CRIAR_PEDIDO", "system", pedido_id, {"negociacaoId": dto.negociacao_id})

    if idempotency_key:
        save_idempotent_response(idempotency_key, 201, record)

    return record

@app.get("/api/v1/pedidos")
async def listar_pedidos():
    return list(db_pedidos.values())

@app.get("/api/v1/pedidos/{id}")
async def obter_pedido(id: str):
    if id not in db_pedidos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Pedido inexistente.")
    return db_pedidos[id]

@app.get("/api/v1/pedidos/{id}/historico")
async def obter_historico_pedido(id: str):
    # RF-10: GET /api/v1/pedidos/{id}/historico lista as transicoes com data
    if id not in db_pedidos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Pedido inexistente.")
    return db_historico.get(id, [])

@app.patch("/api/v1/pedidos/{id}/status")
async def atualizar_status_pedido(id: str, dto: StatusUpdateRequest):
    # RF-10: Estados CRIADO -> AGUARDANDO_FRETE -> FRETE_SELECIONADO -> ENTREGUE (ou CANCELADO)
    if id not in db_pedidos:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Pedido inexistente.")

    pedido = db_pedidos[id]
    status_atual = pedido["status"]
    novo = dto.novo_status.upper()

    transicoes_permitidas = VALID_TRANSITIONS.get(status_atual, [])
    # RF-10: Transição inválida -> 409
    if novo not in transicoes_permitidas:
        raise ProblemException(
            status_code=409,
            title="Transição Inválida",
            detail=f"Não é permitido transitar pedido do status '{status_atual}' para '{novo}'. Transições válidas: {transicoes_permitidas} (RF-10)."
        )

    now = datetime.now(timezone.utc).isoformat()
    pedido["status"] = novo
    db_historico[id].append({
        "status_anterior": status_atual,
        "status_novo": novo,
        "data_transicao": now
    })

    # RF-10: Cada transição publica pedido_atualizado
    payload_atualizado = {
        "pedidoId": id,
        "statusAnterior": status_atual,
        "novoStatus": novo,
        "timestamp": now
    }
    await publish_event(
        event_type="pedido_atualizado",
        source=SERVICE_NAME,
        aggregate_id=id,
        payload=payload_atualizado
    )

    record_audit(SERVICE_NAME, "ATUALIZAR_STATUS_PEDIDO", "system", id, payload_atualizado)
    return pedido
