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
from common.idempotency import get_idempotent_response, save_idempotent_response

SERVICE_NAME = "negociacao-service"
PORT = 8106

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Negociação e Leilão API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_negociacoes = {}
db_lances = {}

class NegociacaoCreate(BaseModel):
    id: Optional[str] = None
    modo: str = Field("VENDA_DIRETA", description="VENDA_DIRETA, LEILAO_DIRETO, LEILAO_REVERSO")
    valor_inicial: float = Field(..., gt=0)
    fornecedor_id: Optional[str] = None
    comprador_id: Optional[str] = None

class LanceCreate(BaseModel):
    empresa_id: str
    valor: float = Field(..., gt=0)

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 38\n",
        media_type="text/plain"
    )

@app.post("/api/v1/negociacoes", status_code=status.HTTP_201_CREATED)
async def criar_negociacao(dto: NegociacaoCreate):
    neg_id = dto.id or str(uuid.uuid4())
    record = {
        "id": neg_id,
        "modo": dto.modo,
        "status": "ABERTA",
        "lance_atual": dto.valor_inicial,
        "vencedor_id": dto.comprador_id or dto.fornecedor_id,
        "lances": []
    }
    db_negociacoes[neg_id] = record
    return record

@app.get("/api/v1/negociacoes")
async def listar_negociacoes():
    return list(db_negociacoes.values())

@app.get("/api/v1/negociacoes/{id}")
async def obter_negociacao(id: str):
    if id not in db_negociacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Negociação inexistente.")
    return db_negociacoes[id]

@app.post("/api/v1/negociacoes/{id}/lances", status_code=status.HTTP_201_CREATED)
async def enviar_lance(
    id: str,
    dto: LanceCreate,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key")
):
    # CT-A06: Idempotência em operação crítica
    if idempotency_key:
        cached = get_idempotent_response(idempotency_key)
        if cached:
            return cached

    if id not in db_negociacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Negociação não encontrada.")

    neg = db_negociacoes[id]
    if neg["status"] != "ABERTA":
        raise ProblemException(status_code=409, title="Negociação Fechada", detail="Não é possível enviar lances em negociação fechada.")

    modo = neg["modo"]
    lance_atual = neg["lance_atual"]

    # RF-08: Regra de validação de lances
    if modo == "LEILAO_DIRETO":
        # Dado um leilão direto, quando um lance <= lance atual é enviado, então 409
        if dto.valor <= lance_atual:
            raise ProblemException(
                status_code=409,
                title="Lance Inválido (Leilão Direto)",
                detail=f"Em leilão direto, o novo lance ({dto.valor}) deve ser estritamente maior que o lance atual ({lance_atual}) (RF-08)."
            )
    elif modo == "LEILAO_REVERSO":
        # Em leilão reverso, o novo lance deve ser estritamente MENOR que o lance atual
        if dto.valor >= lance_atual:
            raise ProblemException(
                status_code=409,
                title="Lance Inválido (Leilão Reverso)",
                detail=f"Em leilão reverso, o novo lance ({dto.valor}) deve ser estritamente menor que o lance atual ({lance_atual}) (RF-08)."
            )

    lance_id = str(uuid.uuid4())
    lance_record = {
        "id": lance_id,
        "negociacao_id": id,
        "empresa_id": dto.empresa_id,
        "valor": dto.valor
    }
    neg["lance_atual"] = dto.valor
    neg["vencedor_id"] = dto.empresa_id
    neg["lances"].append(lance_record)

    # RF-08: com lance maior (ou menor em reverso), 201 e lance_realizado publicado
    await publish_event(
        event_type="lance_realizado",
        source=SERVICE_NAME,
        aggregate_id=id,
        payload=lance_record
    )

    if idempotency_key:
        save_idempotent_response(idempotency_key, 201, lance_record)

    return lance_record

@app.post("/api/v1/negociacoes/{id}/encerrar")
async def encerrar_negociacao(id: str):
    # RF-08: Ao encerrar, o vencedor é definido e negociacao_fechada é publicado
    if id not in db_negociacoes:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Negociação não encontrada.")

    neg = db_negociacoes[id]
    neg["status"] = "FECHADA"

    payload_fechada = {
        "negociacaoId": id,
        "modo": neg["modo"],
        "vencedorId": neg["vencedor_id"],
        "valorFinal": neg["lance_atual"],
        "status": "FECHADA"
    }

    # RF-08: Publica negociacao_fechada
    await publish_event(
        event_type="negociacao_fechada",
        source=SERVICE_NAME,
        aggregate_id=id,
        payload=payload_fechada
    )

    return payload_fechada
