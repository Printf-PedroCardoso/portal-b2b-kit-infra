# CATÁLOGO DE CONTRATOS DE EVENTOS — PORTAL B2B DISTRIBUÍDO
**Versão:** 1.0 (CT-E08)  
**Schema Registry:** Redpanda embutido (`http://localhost:18081` ou `rp-0:18081`)  
**Política de Compatibilidade:** `BACKWARD` (CT-E07)  
**Partições por Tópico:** 3 (CT-E09)  
**Fator de Replicação:** 3 (`min.insync.replicas=2` - RNF-42)  
**Retenção:** 7 dias (`retention.ms=604800000` - RNF-43); DLTs 14 dias  

---

## 1. Envelope Padrão Obrigatório (CT-E01)

Todos os eventos emitidos pelos microsserviços utilizam o seguinte envelope estrito em formato JSON:

```json
{
  "eventId": "uuid (identificador único do evento)",
  "eventType": "nome_do_topico",
  "eventVersion": "1.0",
  "timestamp": "ISO-8601 UTC (ex: 2026-10-22T20:30:00.000Z)",
  "source": "nome-do-servico-produtor",
  "correlationId": "uuid para rastreabilidade ponta a ponta (RF-15)",
  "aggregateId": "id da entidade de negócio (chave de partição - CT-E02)",
  "payload": {}
}
```

---

## 2. Matriz dos 15 Tópicos de Negócio (CT-E08, CT-E09)

| # | Nome do Tópico | Serviço Dono (Produtor) | Serviços Consumidores | Chave de Partição (`aggregateId`) |
|---|---|---|---|---|
| 1 | `empresa_cadastrada` | `usuarios-service` | `fornecimentos-service`, `demanda-service`, `transportadoras-service` | `empresaId` |
| 2 | `produto_cadastrado` | `produtos-service` | `fornecimentos-service`, `demanda-service`, `mercado-service` | `produtoId` |
| 3 | `fornecimento_criado` | `fornecimentos-service` | `mercado-service` | `fornecimentoId` |
| 4 | `estoque_atualizado` | `fornecimentos-service` | `mercado-service` | `fornecimentoId` |
| 5 | `demanda_criada` | `demanda-service` | `mercado-service` | `demandaId` |
| 6 | `demanda_recorrente_gerada` | `demanda-service` | `mercado-service` | `demandaRecorrenteId` |
| 7 | `modo_negociacao_definido` | `mercado-service` | `negociacao-service` | `negociacaoId` |
| 8 | `leilao_iniciado` | `mercado-service` | `negociacao-service` | `negociacaoId` |
| 9 | `lance_realizado` | `negociacao-service` | `mercado-service` | `negociacaoId` |
| 10 | `negociacao_fechada` | `negociacao-service` | `pedidos-service` | `negociacaoId` |
| 11 | `pedido_criado` | `pedidos-service` | `logistica-service` | `pedidoId` |
| 12 | `pedido_atualizado` | `pedidos-service` | `logistica-service` | `pedidoId` |
| 13 | `solicitacao_frete_criada` | `logistica-service` | `transportadoras-service` | `solicitacaoFreteId` |
| 14 | `cotacao_recebida` | `transportadoras-service` | `logistica-service` | `solicitacaoFreteId` |
| 15 | `frete_selecionado` | `logistica-service` | `pedidos-service` | `pedidoId` |

### Tópicos de Falha / Dead Letter (CT-E06)
Cada serviço consumidor possui seu respectivo tópico DLT para mensagens não processáveis após 3 tentativas:
- `usuarios.dlt`
- `produtos.dlt`
- `fornecimentos.dlt`
- `demanda.dlt`
- `mercado.dlt`
- `negociacao.dlt`
- `pedidos.dlt`
- `logistica.dlt`
- `transportadoras.dlt`
