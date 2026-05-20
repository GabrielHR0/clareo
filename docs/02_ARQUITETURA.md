# Arquitetura de Sistema - Clareo

## Diagrama de Alto Nível

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend Layer                           │
│         (Web Dashboard + Mobile App - Future)                │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    API Gateway                                │
│  (Rate Limiting, Authentication, Routing)                    │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Rails Application Layer                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ Organizations    │  │ Donations        │                  │
│  │ Microservice     │  │ Microservice     │                  │
│  └──────────────────┘  └──────────────────┘                  │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ Wallet Service   │  │ Transactions     │                  │
│  │                  │  │ Microservice     │                  │
│  └──────────────────┘  └──────────────────┘                  │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ Credit Service   │  │ Ledger Service   │                  │
│  │                  │  │ (Audit Trail)    │                  │
│  └──────────────────┘  └──────────────────┘                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Background Jobs (Sidekiq)                    │   │
│  │  - Process Recurring Donations                       │   │
│  │  - Apply Floating (Investment)                       │   │
│  │  - Reconciliation                                    │   │
│  └──────────────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────┬────────────────┘
         │                                    │
    ┌────▼────────────────────┐  ┌───────────▼──────────────┐
    │    Cassandra Cluster    │  │  Redis Cache/Sessions   │
    │  (3+ Nodes Min)         │  │  + Distributed Locks    │
    │  Replication: 3         │  └───────────────────────┘
    └─────────────────────────┘
         │
    ┌────▼────────────────────┐
    │  Apache Kafka Cluster   │
    │  (Event Streaming)      │
    │  - donation.created     │
    │  - transaction.posted   │
    │  - floating.interest    │
    │  - audit.events         │
    └─────────────────────────┘
```

## Camadas da Arquitetura

### 1. API Gateway
- Autenticação JWT
- Rate limiting por usuário/organização
- Request/response logging
- Redirecionamento para serviços

### 2. Camada de Aplicação (Rails)
Serviços independentes que compartilham BD:
- **Organizations**: CRUD, configuração de planos
- **Donations**: Processamento de doações recorrentes
- **Wallet**: Gerenciamento de saldo
- **Transactions**: Histórico e processamento
- **Credit**: Sistema de crédito
- **Ledger**: Auditoria e reconstrução de estado

### 3. Camada de Dados
- **Cassandra**: Dados transacionais, ledger, histórico
- **Redis**: Cache, locks distribuídos, sessões
- **Elasticsearch**: Logs e busca (future)

### 4. Processamento Assíncrono
- **Sidekiq + Redis**: Fila de jobs para processamento rápido
- **Kafka**: Event streaming para eventos de negócio (auditoria, webhooks, replicação de dados)
- **Cron jobs**: Processamentos periódicos (doações recorrentes, aplicação de floating, reconciliação)

### 5. Event Streaming com Kafka
Tópicos principais:
- `donations.created` - Doação criada
- `donations.recurring.processed` - Doação recorrente processada
- `transactions.posted` - Transação confirmada
- `wallets.balance_changed` - Saldo alterado
- `floating.interest_applied` - Juros aplicados
- `credit.line_used` - Crédito utilizado
- `audit.events` - Todos eventos para auditoria

**Benefícios**:
- Auditoria distribuída
- Webhooks para integrações (futuro)
- Event sourcing para reconstrução de estado
- Desacoplamento entre serviços
- Escalabilidade de consumers

---

## Padrões de Consistência

### Para Operações Críticas (Transações Financeiras)

```
┌──────────────────────────────────────────────────┐
│ 1. Request chega com idempotency_key             │
├──────────────────────────────────────────────────┤
│ 2. Verificar se já foi processado (Redis cache)  │
├──────────────────────────────────────────────────┤
│ 3. Adquirir lock distribuído (organização)       │
├──────────────────────────────────────────────────┤
│ 4. Validar e preparar transação                  │
├──────────────────────────────────────────────────┤
│ 5. Executar Lightweight Transaction em Cassandra │
├──────────────────────────────────────────────────┤
│ 6. Registrar em Ledger imutável                  │
├──────────────────────────────────────────────────┤
│ 7. Atualizar cache                               │
├──────────────────────────────────────────────────┤
│ 8. Liberar lock e retornar sucesso               │
└──────────────────────────────────────────────────┘
```

### Saga Pattern para Transações Distribuídas
Quando envolver múltiplos serviços:
1. Criar saga com estado
2. Executar passos sequencialmente
3. Em caso de erro, reverter com compensating transactions

---

## Sharding Strategy

```
Organization → Shard Key
├─ organization_id % num_shards → Partição Cassandra
└─ Todas as transações dessa org vão para mesma partição
```

**Benefícios**:
- Melhor distribuição de carga
- Queries locais são mais rápidas
- Menos contenção por locks

---

## Escalabilidade Esperada
- **Throughput**: 10k+ requisições/segundo (com 3+ nós Cassandra)
- **Latência p99**: <200ms
- **Disponibilidade**: 99.95%

