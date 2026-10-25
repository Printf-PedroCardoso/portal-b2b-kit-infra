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

SERVICE_NAME = "transportadoras-service"
PORT = 8109

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Transportadoras API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

# Seed inicial de transportadoras homologadas (RF-11.2)
db_transportadoras = {
    "transp-alpha": {"id": "transp-alpha", "nome": "Transportadora Alpha Express", "preco_base": 150.0, "prazo_dias": 3},
    "transp-beta": {"id": "transp-beta", "nome": "Transportadora Beta Log", "preco_base": 120.0, "prazo_dias": 5}
}

class RespostaCotacaoRequest(BaseModel):
    solicitacao_frete_id: str

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 22\n",
        media_type="text/plain"
    )

@app.get("/api/v1/transportadoras")
async def listar_transportadoras():
    return list(db_transportadoras.values())

@app.post("/api/v1/transportadoras/responder-solicitacao", status_code=status.HTTP_201_CREATED)
async def responder_solicitacao(dto: RespostaCotacaoRequest):
    # RF-11.2: Dada uma solicitacao, quando duas transportadoras cadastradas (seed)
    # respondem, entao ha >= 2 cotacao_recebida em <= 10s, com preco e prazo.
    cotacoes_geradas = []

    for transp_id, transp in db_transportadoras.items():
        cotacao_id = str(uuid.uuid4())
        cotacao_payload = {
            "cotacaoId": cotacao_id,
            "solicitacaoFreteId": dto.solicitacao_frete_id,
            "transportadoraId": transp_id,
            "preco": transp["preco_base"],
            "prazoDias": transp["prazo_dias"]
        }
        cotacoes_geradas.append(cotacao_payload)

        # RF-11.2: Publica cotacao_recebida
        await publish_event(
            event_type="cotacao_recebida",
            source=SERVICE_NAME,
            aggregate_id=dto.solicitacao_frete_id,
            payload=cotacao_payload
        )
        logger.info(f"Cotacao emitida por {transp_id} para solicitacao {dto.solicitacao_frete_id}")

    return {"status": "cotacoes_emitidas", "total": len(cotacoes_geradas), "cotacoes": cotacoes_geradas}
