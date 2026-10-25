import os
import json
import asyncio
import traceback
from typing import Callable, Awaitable, Dict, Any, Set
from .logger import setup_logger
from .events import publish_event

logger = setup_logger("event-consumer")

# Registro em memória de eventos processados por serviço (CT-E04)
# Na persistência relacional, mapeia para a tabela processed_events(event_id, processed_at)
_processed_events_cache: Dict[str, Set[str]] = {}

def is_event_processed(service_name: str, event_id: str) -> bool:
    """
    Verifica se o evento já foi processado para garantir idempotência (CT-E04).
    """
    service_cache = _processed_events_cache.setdefault(service_name, set())
    return event_id in service_cache

def mark_event_processed(service_name: str, event_id: str):
    """
    Marca o evento como processado na tabela processed_events (CT-E04).
    """
    service_cache = _processed_events_cache.setdefault(service_name, set())
    service_cache.add(event_id)

async def handle_incoming_event(
    service_name: str,
    event: Dict[str, Any],
    handler: Callable[[Dict[str, Any]], Awaitable[None]]
) -> bool:
    """
    Processador de eventos com idempotência (CT-E04), retentativas exponenciais (CT-E05)
    e encaminhamento para Dead Letter Topic em caso de falha persistente (CT-E06).
    """
    event_id = event.get("eventId")
    event_type = event.get("eventType")

    if not event_id:
        logger.error(f"[{service_name}] Evento rejeitado: sem eventId no envelope.")
        return False

    # Idempotência: descarte sem duplicar efeito (CT-E04)
    if is_event_processed(service_name, event_id):
        logger.info(f"[{service_name}] Evento duplicado descartado com idempotência: {event_id} ({event_type})")
        return True

    # Política de Retry com backoff: 3 tentativas (1s, 2s, 4s) (CT-E05)
    delays = [1, 2, 4]
    max_attempts = len(delays)

    for attempt in range(1, max_attempts + 1):
        try:
            logger.info(f"[{service_name}] Processando {event_type} (tentativa {attempt}/{max_attempts})...")
            await handler(event)
            mark_event_processed(service_name, event_id)
            logger.info(f"[{service_name}] Evento {event_id} processado com sucesso.")
            return True
        except Exception as exc:
            logger.warning(f"[{service_name}] Falha na tentativa {attempt} para evento {event_id}: {exc}")
            if attempt < max_attempts:
                await asyncio.sleep(delays[attempt - 1])
            else:
                # Falha definitiva: envio ao DLT com detalhes do erro (CT-E06)
                dlt_topic = f"{service_name}.dlt"
                logger.error(f"[{service_name}] Excedidas 3 tentativas. Enviando evento {event_id} ao DLT '{dlt_topic}'.")
                dlt_payload = {
                    "originalEvent": event,
                    "error": str(exc),
                    "stackTrace": traceback.format_exc(),
                    "failedAtAttempt": attempt
                }
                await publish_event(
                    event_type=dlt_topic,
                    source=service_name,
                    aggregate_id=event.get("aggregateId", "unknown"),
                    payload=dlt_payload,
                    correlation_id=event.get("correlationId")
                )
                return False

    return False
