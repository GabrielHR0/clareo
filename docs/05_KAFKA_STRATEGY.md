# Estratégia de Event Streaming com Kafka - Clareo

## Por que Kafka?

1. **Auditoria Distribuída**: Todos eventos financeiros são imutáveis e rastreáveis
2. **Desacoplamento**: Serviços não dependem uns dos outros em tempo real
3. **Escalabilidade**: Consumers podem processar eventos independentemente
4. **Replicação de Dados**: Pode alimentar data warehouse, analytics
5. **Webhooks Futuros**: Base para integrações com sistemas externos
6. **Event Sourcing**: Reconstruir estado de uma organização a partir de eventos

---

## Tópicos Kafka

### 1. **donations.created**
Quando uma doação é criada (uma única vez, não recorrente)
```json
{
  "event_id": "uuid",
  "organization_id": "uuid",
  "contributor_id": "uuid",
  "amount_cents": 10000,
  "plan_id": "uuid",
  "timestamp": "2026-05-19T19:00:00Z",
  "idempotency_key": "key"
}
```
- Partição por `organization_id`
- Retention: 30 dias (auditoria)

### 2. **donations.recurring.processed**
Quando uma doação recorrente é processada (job diário)
```json
{
  "event_id": "uuid",
  "recurring_id": "uuid",
  "organization_id": "uuid",
  "contributor_id": "uuid",
  "amount_cents": 10000,
  "batch_id": "uuid",
  "processed_date": "2026-05-19",
  "timestamp": "2026-05-19T19:00:00Z"
}
```
- Partição por `organization_id`
- Retention: 90 dias

### 3. **transactions.posted**
Após transação ser registrada em Cassandra com sucesso
```json
{
  "event_id": "uuid",
  "transaction_id": "uuid",
  "organization_id": "uuid",
  "type": "donation|withdrawal|credit|floating_return",
  "amount_cents": 10000,
  "new_balance_cents": 150000,
  "status": "completed",
  "timestamp": "2026-05-19T19:00:00Z",
  "metadata": {}
}
```
- Partição por `organization_id`
- Retention: 1 ano

### 4. **wallets.balance_changed**
Sempre que saldo de uma organização muda
```json
{
  "event_id": "uuid",
  "organization_id": "uuid",
  "old_balance_cents": 140000,
  "new_balance_cents": 150000,
  "change_reason": "donation|withdrawal|interest",
  "timestamp": "2026-05-19T19:00:00Z"
}
```
- Partição por `organization_id`
- Retention: 1 ano

### 5. **floating.interest_applied**
Juros da aplicação flutuante calculados e creditados
```json
{
  "event_id": "uuid",
  "floating_id": "uuid",
  "organization_id": "uuid",
  "principal_cents": 100000,
  "interest_cents": 2500,
  "applied_date": "2026-05-19",
  "annual_rate": 0.15,
  "timestamp": "2026-05-19T19:00:00Z"
}
```
- Partição por `organization_id`
- Retention: 2 anos

### 6. **credit.line_used**
Quando crédito é utilizado ou devolvido
```json
{
  "event_id": "uuid",
  "credit_id": "uuid",
  "organization_id": "uuid",
  "used_amount_cents": 50000,
  "total_limit_cents": 100000,
  "available_cents": 50000,
  "timestamp": "2026-05-19T19:00:00Z"
}
```
- Partição por `organization_id`
- Retention: 2 anos

### 7. **audit.events**
Todos eventos de segurança/conformidade
```json
{
  "event_id": "uuid",
  "organization_id": "uuid",
  "user_id": "uuid",
  "action": "login|update_wallet|withdraw|access_api",
  "resource_id": "uuid",
  "ip_address": "127.0.0.1",
  "user_agent": "string",
  "status": "success|failure",
  "error_message": null,
  "timestamp": "2026-05-19T19:00:00Z"
}
```
- Partição por `organization_id`
- Retention: 7 anos (conformidade legal)

## Como habilitar no ambiente local

1. Defina `KAFKA_BROKERS` no `.env` ou `.env.development`.
2. Suba um broker Kafka acessível em `kafka:9092` no `docker-compose.dev.yml`.
3. Rode a task para criar os tópicos:

```bash
bundle exec rake kafka:create_topics
```

4. Se Kafka não estiver disponível, o sistema continua funcionando e os eventos são apenas logados.

---

## Consumer Groups

### 1. **Webhook Service** (future)
Consome: `donations.created`, `transactions.posted`, `floating.interest_applied`
- Envia webhooks para clientes
- Retry com backoff exponencial
- DLQ para falhas

### 2. **Analytics Service** (future)
Consome: Todos tópicos
- Alimenta data warehouse
- Calcula KPIs
- Dashboards

### 3. **Notification Service** (phase 2)
Consome: `donations.created`, `floating.interest_applied`, `credit.line_used`
- Envia emails/SMS
- Notificações push

### 4. **Reconciliation Service** (phase 3)
Consome: `transactions.posted`, `wallets.balance_changed`
- Verifica consistency entre Kafka e Cassandra
- Identifica anomalias
- Alertas

### 5. **Audit Logger** (phase 4)
Consome: `audit.events`
- Registra em banco segregado (compliance)
- Torna imutável
- Replicação para 3º lugar

---

## Padrão de Publish

Em cada operação crítica:

```ruby
# 1. Executar operação em Cassandra com LWT
transaction = Transaction.create(...)

# 2. Publicar evento em Kafka
KafkaProducer.publish('transactions.posted', {
  event_id: SecureRandom.uuid,
  transaction_id: transaction.id,
  organization_id: transaction.organization_id,
  amount_cents: transaction.amount_cents,
  timestamp: Time.current.iso8601
})

# 3. Retornar resposta ao cliente
```

### Garantias
- **At-least-once delivery**: Kafka garante, consumer deve ser idempotente
- **Ordering**: Particionar por `organization_id` garante ordem dentro de org
- **Durability**: Replicação em 3 brokers

---

## Configuration Cassandra/Kafka

### Docker Compose (exemplo)
```yaml
kafka:
  image: confluentinc/cp-kafka:7.3.0
  environment:
    KAFKA_BROKER_ID: 1
    KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
    KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
    KAFKA_LOG_RETENTION_HOURS: 720 # 30 dias padrão
    KAFKA_NUM_PARTITIONS: 3
```

### Partição Strategy
- 3 partições por tópico (escalável a 3 consumers)
- Partition key: `organization_id` (hash)
- Distribuição uniforme de load

---

## Monitoramento Kafka

### Métricas
- Consumer lag (atraso de processamento)
- Throughput (msg/s)
- Error rate
- Rebalancing frequency

### Alertas
- Lag > 1 hora
- Error rate > 1%
- Broker desligado
- Disk space < 20%

---

## Segurança

- **SASL/SCRAM**: Autenticação entre producers/consumers
- **SSL/TLS**: Criptografia em trânsito
- **ACLs**: Controle de acesso por tópico
- **Audit Logging**: Todos acessos registrados

