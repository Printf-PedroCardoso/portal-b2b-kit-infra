import sys
import os
import uuid
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Request, Response, status, Query
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event

SERVICE_NAME = "mercado-service"
PORT = 8105

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Mercado e Matching Engine API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_matches = {}
db_modos = {}

# Repositórios locais mantidos a partir de eventos consumidos
known_fornecimentos = {}
known_demandas = {}

class MatchManualRequest(BaseModel):
    demanda_id: str
    fornecimento_id: str

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 50\n",
        media_type="text/plain"
    )

@app.post("/api/v1/mercado/sync-oferta")
async def sync_oferta(payload: Dict[str, Any]):
    """Recebe e indexa fornecimentos em memória."""
    fornec_id = payload.get("id") or payload.get("fornecimentoId")
    if fornec_id:
        known_fornecimentos[fornec_id] = payload
    return {"status": "synced", "id": fornec_id}

@app.post("/api/v1/mercado/sync-demanda")
async def sync_demanda(payload: Dict[str, Any]):
    """Recebe e indexa demandas em memória."""
    dem_id = payload.get("id") or payload.get("demandaId")
    if dem_id:
        known_demandas[dem_id] = payload
    return {"status": "synced", "id": dem_id}

@app.post("/api/v1/mercado/executar-matching")
async def executar_matching():
    """
    Motor reativo de matching (RF-06):
    Regra: mesmo produto, quantidade ofertada >= quantidade demandada,
    e preco ofertado <= preco_teto (quando informado).
    """
    matches_criados = []

    for d_id, dem in list(known_demandas.items()):
        for f_id, forn in list(known_fornecimentos.items()):
            # 1. Checagem de produto compatível
            if dem.get("produto_id") != forn.get("produto_id"):
                continue

            # 2. Quantidade ofertada >= demandada
            qtd_forn = float(forn.get("quantidade_disponivel", 0))
            qtd_dem = float(dem.get("quantidade", 0))
            if qtd_forn < qtd_dem:
                continue

            # 3. Preço <= Preço Teto
            preco_forn = float(forn.get("preco", 0))
            preco_teto = dem.get("preco_teto")
            if preco_teto is not None and preco_forn > float(preco_teto):
                continue

            # Match compatível localizado! (RF-06)
            match_id = str(uuid.uuid4())
            match_record = {
                "id": match_id,
                "demanda_id": d_id,
                "fornecimento_id": f_id,
                "produto_id": dem.get("produto_id"),
                "status": "COMPATIVEL"
            }
            db_matches[match_id] = match_record
            matches_criados.append(match_record)

            # Determinação do modo de negociação (RF-07, Regra D-10)
            # Para 1 oferta x 1 demanda -> VENDA_DIRETA
            # Se múltiplos, leilão direto ou reverso
            negociacao_id = str(uuid.uuid4())
            modo = "VENDA_DIRETA" # Modo padrão 1x1

            db_modos[match_id] = {
                "negociacaoId": negociacao_id,
                "matchId": match_id,
                "modo": modo
            }

            # Publicação de modo_negociacao_definido (RF-07)
            await publish_event(
                event_type="modo_negociacao_definido",
                source=SERVICE_NAME,
                aggregate_id=negociacao_id,
                payload={
                    "negociacaoId": negociacao_id,
                    "matchId": match_id,
                    "modo": modo,
                    "fornecimentoId": f_id,
                    "demandaId": d_id,
                    "produtoId": dem.get("produto_id"),
                    "quantidade": qtd_dem,
                    "valorInicial": preco_forn,
                    "compradorId": dem.get("comprador_id"),
                    "fornecedorId": forn.get("fornecedor_id")
                }
            )

    return {"matches": matches_criados, "total": len(matches_criados)}

@app.get("/api/v1/mercado/matches")
async def listar_matches():
    return list(db_matches.values())

@app.post("/api/v1/mercado/definir-modo")
async def definir_modo_arbitrario(
    match_id: str,
    qtd_ofertas: int = 1,
    qtd_demandas: int = 1
):
    """
    Aplica a regra exata D-10 de RF-07:
    - 1 oferta x 1 demanda = VENDA_DIRETA
    - 1 oferta x N demandas = LEILAO_DIRETO
    - 1 demanda x N ofertas = LEILAO_REVERSO
    """
    if qtd_ofertas == 1 and qtd_demandas == 1:
        modo = "VENDA_DIRETA"
    elif qtd_ofertas == 1 and qtd_demandas > 1:
        modo = "LEILAO_DIRETO"
    elif qtd_demandas == 1 and qtd_ofertas > 1:
        modo = "LEILAO_REVERSO"
    else:
        modo = "VENDA_DIRETA"

    negociacao_id = str(uuid.uuid4())
    payload = {
        "negociacaoId": negociacao_id,
        "matchId": match_id,
        "modo": modo
    }
    db_modos[match_id] = payload

    await publish_event(
        event_type="modo_negociacao_definido",
        source=SERVICE_NAME,
        aggregate_id=negociacao_id,
        payload=payload
    )

    if modo in ["LEILAO_DIRETO", "LEILAO_REVERSO"]:
        # RF-07: se leilão, publica leilao_iniciado
        await publish_event(
            event_type="leilao_iniciado",
            source=SERVICE_NAME,
            aggregate_id=negociacao_id,
            payload={
                "negociacaoId": negociacao_id,
                "matchId": match_id,
                "tipoLeilao": modo
            }
        )

    return payload
