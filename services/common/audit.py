import os
from datetime import datetime, timezone
from typing import Dict, Any, List
from .logger import setup_logger, correlation_id_ctx

logger = setup_logger("audit-service")

# Armazenamento imutável de trilha de auditoria (RNF-24)
_audit_trail: List[Dict[str, Any]] = []

def record_audit(
    service_name: str,
    action: str,
    user_id: str,
    entity_id: str,
    details: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Grava registro de auditoria imutável (quem, quando, o quê, correlationId).
    Apenas INSERT é permitido; UPDATE e DELETE são bloqueados (RNF-24).
    """
    corr_id = correlation_id_ctx.get() or "none"
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": service_name,
        "action": action,
        "userId": user_id,
        "entityId": entity_id,
        "correlationId": corr_id,
        "details": details
    }
    _audit_trail.append(entry)
    logger.info(f"[AUDIT] {action} executada por {user_id} sobre {entity_id} (corr={corr_id})")
    return entry

def get_audit_trail() -> List[Dict[str, Any]]:
    return list(_audit_trail)
