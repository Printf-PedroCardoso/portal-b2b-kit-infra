import os
import sys
import json
import logging
from datetime import datetime, timezone
from contextvars import ContextVar
from typing import Optional

# Variável de contexto assíncrona para propagação do Correlation ID
correlation_id_ctx: ContextVar[Optional[str]] = ContextVar("correlation_id_ctx", default=None)

class JsonLogFormatter(logging.Formatter):
    """
    Formatador de logs JSON para stdout/stderr conforme requisitos SW-07, RF-15 e RNF-27.
    """
    def __init__(self, service_name: str):
        super().__init__()
        self.service_name = service_name

    def format(self, record: logging.LogRecord) -> str:
        corr_id = correlation_id_ctx.get() or getattr(record, "correlationId", "none")
        
        # Sanitização LGPD (RNF-27): nunca logar senhas ou segredos
        message = record.getMessage()
        if "senha" in message.lower() or "password" in message.lower() or "secret" in message.lower():
            message = "[LOG SANITIZADO - DADO SENSÍVEL REMOVIDO]"

        log_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": self.service_name,
            "correlationId": corr_id,
            "message": message,
            "logger": record.name
        }

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data, ensure_ascii=False)

def setup_logger(service_name: str, level: str = "INFO") -> logging.Logger:
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLogFormatter(service_name))
    logger.addHandler(handler)
    logger.propagate = False
    return logger
