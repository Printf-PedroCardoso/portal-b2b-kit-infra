import sys
import os
import uuid
import asyncio
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import FastAPI, Request, Response, status, Query
from pydantic import BaseModel, Field

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.events import publish_event

SERVICE_NAME = "demanda-service"
PORT = 8104

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Demanda API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

db_demandas = {}
recorrentes_em_execucao = {}

class DemandaCreate(BaseModel):
    comprador_id: str
    produto_id: str
    quantidade: float = Field(..., gt=0)
    preco_teto: Optional[float] = Field(None, gt=0)
    tipo: str = Field("PONTUAL", description="PONTUAL ou RECORRENTE (RF-05.1, RF-05.2)")
    frequencia_segundos: Optional[int] = Field(0, description="Frequência em segundos para demandas recorrentes")

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
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 19\n",
        media_type="text/plain"
    )

async def ciclo_demanda_recorrente(demanda_id: str, freq: int):
    """
    Worker em background para gerar eventos demanda_recorrente_gerada (RF-05.2).
    """
    logger.info(f"Iniciando ciclo recorrente para demanda {demanda_id} a cada {freq}s")
    while demanda_id in db_demandas and db_demandas[demanda_id].get("ativo", True):
        await asyncio.sleep(freq)
        demanda = db_demandas.get(demanda_id)
        if not demanda:
            break

        rec_id = str(uuid.uuid4())
        payload = {
            "demandaRecorrenteId": rec_id,
            "demandaPaiId": demanda_id,
            "compradorId": demanda["comprador_id"],
            "produtoId": demanda["produto_id"],
            "quantidade": demanda["quantidade"],
            "precoTeto": demanda["preco_teto"],
            "cicloTimestamp": datetime.now(timezone.utc).isoformat()
        }

        # RF-05.2: Publica demanda_recorrente_gerada
        await publish_event(
            event_type="demanda_recorrente_gerada",
            source=SERVICE_NAME,
            aggregate_id=rec_id,
            payload=payload
        )
        logger.info(f"Ciclo gerado com sucesso: {rec_id} para demanda {demanda_id}")

@app.post("/api/v1/demandas", status_code=status.HTTP_201_CREATED)
async def criar_demanda(dto: DemandaCreate):
    demanda_id = str(uuid.uuid4())
    record = {
        "id": demanda_id,
        "comprador_id": dto.comprador_id,
        "produto_id": dto.produto_id,
        "quantidade": dto.quantidade,
        "preco_teto": dto.preco_teto,
        "tipo": dto.tipo,
        "frequencia_segundos": dto.frequencia_segundos,
        "ativo": True,
        "criado_em": datetime.now(timezone.utc).isoformat()
    }
    db_demandas[demanda_id] = record

    if dto.tipo.upper() == "PONTUAL":
        # RF-05.1: Publica demanda_criada
        await publish_event(
            event_type="demanda_criada",
            source=SERVICE_NAME,
            aggregate_id=demanda_id,
            payload=record
        )
    elif dto.tipo.upper() == "RECORRENTE":
        # RF-05.2: Inicia ciclo recorrente
        freq = dto.frequencia_segundos if dto.frequencia_segundos and dto.frequencia_segundos > 0 else 10
        task = asyncio.create_task(ciclo_demanda_recorrente(demanda_id, freq))
        recorrentes_em_execucao[demanda_id] = task

        # Emite primeiro evento de ativação
        await publish_event(
            event_type="demanda_criada",
            source=SERVICE_NAME,
            aggregate_id=demanda_id,
            payload=record
        )

    return record

@app.get("/api/v1/demandas")
async def listar_demandas(
    produto_id: Optional[str] = None,
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100)
):
    itens = list(db_demandas.values())
    if produto_id:
        itens = [d for d in itens if d.get("produto_id") == produto_id]
    start = (page - 1) * size
    return itens[start:start + size]

@app.get("/api/v1/demandas/{id}")
async def obter_demanda(id: str):
    if id not in db_demandas:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Demanda não localizada.")
    return db_demandas[id]
