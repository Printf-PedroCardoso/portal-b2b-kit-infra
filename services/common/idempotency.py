from typing import Optional, Dict, Any
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from .logger import setup_logger

logger = setup_logger("idempotency-manager")

# Cache em memória para chave de idempotência -> resposta gravada (CT-A06)
_idempotency_store: Dict[str, Dict[str, Any]] = {}

def get_idempotent_response(idempotency_key: str) -> Optional[JSONResponse]:
    """
    Retorna resposta em cache caso a chave já tenha sido processada (CT-A06).
    """
    if idempotency_key in _idempotency_store:
        record = _idempotency_store[idempotency_key]
        logger.info(f"Replay idempotente acionado para Idempotency-Key: {idempotency_key}")
        return JSONResponse(
            status_code=record["status_code"],
            content=record["content"],
            headers={"X-Idempotent-Replay": "true"}
        )
    return None

def save_idempotent_response(idempotency_key: str, status_code: int, content: Any):
    """
    Registra a resposta associada à chave de idempotência (CT-A06).
    """
    _idempotency_store[idempotency_key] = {
        "status_code": status_code,
        "content": content
    }
