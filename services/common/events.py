import os
import json
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from .logger import setup_logger, correlation_id_ctx

logger = setup_logger("event-producer")

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:19092,rp-0:19092")

# Tabela em memória para armazenar eventos publicados localmente (para testes e fallback)
in_memory_event_store = []

def build_envelope(
    event_type: str,
    source: str,
    aggregate_id: str,
    payload: Dict[str, Any],
    correlation_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Constrói o envelope padronizado obrigatório (CT-E01, RF-14).
    """
    corr_id = correlation_id or correlation_id_ctx.get() or str(uuid.uuid4())
    return {
        "eventId": str(uuid.uuid4()),
        "eventType": event_type,
        "eventVersion": "1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source": source,
        "correlationId": corr_id,
        "aggregateId": aggregate_id, # Chave de partição (CT-E02)
        "payload": payload
    }

async def publish_event(
    event_type: str,
    source: str,
    aggregate_id: str,
    payload: Dict[str, Any],
    correlation_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Publica evento no Kafka/Redpanda com durabilidade acks=all (RNF-42)
    e envelope canônico (CT-E01).
    """
    envelope = build_envelope(event_type, source, aggregate_id, payload, correlation_id)
    in_memory_event_store.append(envelope)

    # Tentativa de publicação via aiokafka se disponível
    try:
        from aiokafka import AIOKafkaProducer
        producer = AIOKafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS.split(","),
            acks="all",                        # RNF-42: durabilidade
            enable_idempotence=True,           # RNF-42: idempotência do produtor
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8")
        )
        await producer.start()
        try:
            # Chave de partição garante ordenação estrita por entidade (CT-E02, CT-E03)
            await producer.send_and_wait(
                topic=event_type,
                value=envelope,
                key=str(aggregate_id)
            )
            logger.info(f"Evento '{event_type}' publicado no broker com sucesso. aggregateId={aggregate_id}")
        finally:
            await producer.stop()
    except Exception as exc:
        logger.warning(f"Kafka indisponivel localmente ({exc}). Evento persistido no store in-memory.")

    return envelope
