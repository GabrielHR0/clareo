# MVP de Transações + Simulação de BaaS

**Data**: 22 de maio de 2026  
**Objetivo**: Entregar um CRUD de transações funcional, performático e preparado para evoluir para integrações financeiras mais complexas (BaaS real no futuro).

---

## 1) Objetivo do MVP

O MVP deve permitir:

1. Criar transações financeiras por **dono financeiro** (organização ou usuário).
2. Consultar transações por dono e por período.
3. Consultar transações por **campanha** (quando existir campanha vinculada).
3. Simular processamento de pagamento (autorização/captura/falha).
4. Manter consistência de saldo com trilha auditável mínima.
5. Garantir idempotência para evitar transação duplicada.

**Importante**: neste MVP, não precisamos integrar com um BaaS real. Vamos modelar de forma compatível com integração futura.

---

## 2) Princípios de arquitetura (Cassandra-first)

1. **Modelagem por consulta**: cada tabela existe para responder uma consulta específica.
2. **Sem JOIN**: duplicação controlada de dados é aceitável em Cassandra.
3. **Consistência em operação crítica**: usar `QUORUM` em escrita/leitura de dados financeiros.
4. **Idempotência obrigatória**: toda operação externa deve ter `idempotency_key`.
5. **Ledger imutável**: não “editar histórico”, apenas adicionar eventos.

---

## 3) Escopo do domínio (MVP)

### Conceito central

As transações não pertencem diretamente à organização. Elas pertencem a um **owner** (dono financeiro):

- `owner_type`: `organization` ou `user`
- `owner_id`: UUID do dono

Campanha vira um contexto opcional da transação:

- `campaign_id` (nullable)

Assim, uma mesma arquitetura atende:

- campanhas de organizações
- campanhas de usuários comuns
- transações sem campanha

### Entidades mínimas

- `wallets_by_owner` (saldo por dono financeiro)
- `transactions_by_owner` (histórico principal por dono)
- `transactions_by_campaign` (consulta rápida por campanha)
- `idempotency_keys_by_owner` (deduplicação)
- `payment_intents_by_owner` (simulação BaaS)
- `ledger_entries_by_owner` (auditoria mínima)

### Estados mínimos

- Transaction: `pending`, `posted`, `failed`, `reversed`
- PaymentIntent: `created`, `authorized`, `captured`, `failed`, `canceled`

---

## 4) Design de tabelas (Cassandra)

> Ajuste nomes conforme padrão do projeto. O importante é manter a lógica de partition key.

### 4.1 `wallets`

- **Partition key**: `(owner_type, owner_id)`
- Campos: `balance_cents`, `available_cents`, `locked_cents`, `version`, `updated_at`

Consulta alvo:
- obter saldo atual do dono (usuário ou organização)

### 4.2 `transactions_by_owner`

- **Partition key**: `(owner_type, owner_id)`
- **Clustering keys**: `created_at DESC`, `transaction_id`
- Campos: `amount_cents`, `currency`, `type`, `status`, `campaign_id`, `idempotency_key`, `external_reference`, `metadata`

Consulta alvo:
- listar transações do dono (timeline)

### 4.3 `transactions_by_campaign`

- **Partition key**: `campaign_id`
- **Clustering keys**: `created_at DESC`, `transaction_id`
- Campos: `owner_type`, `owner_id`, `amount_cents`, `currency`, `status`

Consulta alvo:
- listar transações de uma campanha sem scan global

### 4.4 `idempotency_keys_by_owner`

- **Partition key**: `(owner_type, owner_id)`
- **Clustering key**: `idempotency_key`
- Campos: `transaction_id`, `request_hash`, `created_at`, `expires_at`

Consulta alvo:
- verificar se a mesma operação já foi processada

### 4.5 `payment_intents_by_owner`

- **Partition key**: `(owner_type, owner_id)`
- **Clustering key**: `payment_intent_id`
- Campos: `amount_cents`, `campaign_id`, `status`, `provider`, `provider_reference`, `authorized_at`, `captured_at`, `failed_reason`

Consulta alvo:
- rastrear ciclo de pagamento simulado (futuro BaaS)

### 4.6 `ledger_entries_by_owner`

- **Partition key**: `(owner_type, owner_id)`
- **Clustering keys**: `created_at DESC`, `entry_id`
- Campos: `transaction_id`, `entry_type(debit|credit)`, `account`, `amount_cents`, `balance_after_cents`

Consulta alvo:
- auditoria financeira e reconciliação por dono

---

## 5) Passo a passo de implementação (MVP)

## Passo 1 — Migrations CQL

Criar arquivos de migration em `db/cassandra/migrations/` para as tabelas acima.

Regras:
- use `CREATE TABLE IF NOT EXISTS`
- use `CREATE INDEX IF NOT EXISTS` apenas quando realmente necessário
- prefira novas tabelas em vez de índice secundário para paths críticos

## Passo 2 — Repositories

Criar repositórios para cada entidade:

- `WalletsByOwnerRepository`
- `TransactionsByOwnerRepository`
- `TransactionsByCampaignRepository`
- `IdempotencyKeysByOwnerRepository`
- `PaymentIntentsByOwnerRepository`
- `LedgerEntriesByOwnerRepository`

Regras:
- prepared statements
- `consistency: :quorum` nas operações financeiras
- UUID normalizado para `Cassandra::Uuid`

## Passo 3 — Services de negócio

Criar serviços para separar regra do controller:

- `ProcessTransactionService`
- `SimulatePaymentService`
- `ReconcileTransactionService` (pode ficar stub no MVP)

Fluxo do `ProcessTransactionService`:
1. validar payload
2. checar idempotency
3. criar `payment_intent` (`created`)
4. simular autorização (`authorized` ou `failed`)
5. se autorizado, criar `transaction` (`pending` -> `posted`)
6. atualizar `wallet`
7. escrever `ledger_entries` (debit/credit)
8. se houver `campaign_id`, escrever `transactions_by_campaign`
8. salvar `idempotency_key`

## Passo 4 — Controllers (CRUD/API)

Endpoints mínimos sugeridos:

- `POST /owners/:owner_type/:owner_id/transactions`
- `GET /owners/:owner_type/:owner_id/transactions`
- `GET /owners/:owner_type/:owner_id/transactions/:id`
- `POST /owners/:owner_type/:owner_id/payment_intents`
- `GET /owners/:owner_type/:owner_id/payment_intents/:id`
- `GET /campaigns/:campaign_id/transactions`

Opcional MVP+:
- `POST /owners/:owner_type/:owner_id/transactions/:id/reverse`

## Passo 5 — Simulador BaaS (adapter)

Criar interface simples:

- `BaasGateway.authorize(...)`
- `BaasGateway.capture(...)`
- `BaasGateway.refund(...)`
- `BaasGateway.status(...)`

Implementação MVP (`FakeBaasGateway`):
- retorna sucesso/falha por regra determinística
- pode usar valor/metadata para simular cenários
- sempre retorna `provider_reference`

Exemplo de regra simples:
- valores múltiplos de 7 -> falha
- demais -> autorizado e capturado

Assim você demonstra comportamento de “provedor externo” sem integrar de verdade.

## Passo 6 — Idempotência

Antes de processar transação:
- buscar `(owner_type, owner_id, idempotency_key)`
- se existir, retornar transação já criada
- se não existir, processar e registrar

Isso evita cobranças duplicadas por retry do cliente.

## Passo 7 — Testes

Mínimo de request specs:
- cria transação com sucesso
- retry com mesma `idempotency_key` não duplica
- cenário de falha no BaaS simulado
- listagem por owner
- listagem por campanha

Mínimo de service specs:
- transição correta de status
- atualização de wallet
- escrita de ledger

---

## 6) Como simular "tempo real" sem complexidade exagerada

Para MVP:
- processamento síncrono no request já é suficiente para demo

Para evoluir sem quebrar arquitetura:
1. manter service layer independente do controller
2. depois mover chamada do `capture` para job assíncrono
3. adicionar fila e retry (Sidekiq)
4. introduzir DLQ/lógica de reprocessamento

---

## 7) Preparando para complexidade futura (roadmap)

## Fase A — MVP pronto

- CRUD de transações
- idempotência
- wallet + ledger
- BaaS fake

## Fase B — Robustez operacional

- outbox pattern para eventos
- retries com backoff
- dead-letter queue
- timeout/circuit-breaker no gateway

## Fase C — Escala e observabilidade

- métricas de throughput, latência, erro por status
- rastreamento por `trace_id`
- reconciliação periódica automática
- dashboards de inconsistência (wallet x ledger)

## Fase D — Integração BaaS real

- trocar `FakeBaasGateway` por adapter real
- manter mesma interface de serviço
- versionar contrato de payload/resposta

---

## 8) Regras funcionais importantes (não negociar)

1. Nenhuma escrita financeira sem `idempotency_key`.
2. Saldo só muda em estado `posted` (não em `created`).
3. Ledger é append-only.
4. Erro parcial em dual write deve gerar compensação/retry.
5. Toda transação deve ter `external_reference` quando houver gateway.

---

## 9) Checklist de pronto do MVP

- [ ] Migrations das 6 tabelas aplicadas
- [ ] Repositórios com prepared statements e QUORUM
- [ ] Serviço `ProcessTransactionService` funcional
- [ ] `FakeBaasGateway` implementado
- [ ] Endpoints de create/list/show por owner funcionando
- [ ] Endpoint de listagem por campanha funcionando
- [ ] Idempotência funcionando com retry
- [ ] Wallet e ledger atualizando de forma consistente
- [ ] Specs principais passando
- [ ] Documentação de fluxo e estados atualizada

---

## 10) Script rápido de demonstração (apresentação)

1. Criar organização
2. Criar usuário comum
3. Criar campanha para usuário (ou organização)
4. Criar transação com `idempotency_key`
3. Repetir mesmo request e mostrar que não duplica
5. Listar transações do owner
6. Listar transações da campanha
5. Mostrar ledger correspondente
6. Simular falha do BaaS e mostrar `failed`

Mensagem para apresentação:

- “Aqui temos modelagem Cassandra orientada à consulta, sem join, com consistência por QUORUM e idempotência para segurança financeira. As transações são desacopladas de organização por meio do conceito de owner (user|organization), com suporte nativo a campanhas.”

---

## 11) Onde isso encaixa no projeto atual

- Reutiliza padrão já aplicado em:
  - organizations
  - contributors
  - memberships
- Mantém o mesmo estilo:
  - migrations CQL
  - repository pattern
  - request specs

Isso reduz risco e mantém o código consistente com o que já está funcionando.

---

## Conclusão

Este plano entrega um MVP funcional de transações com base sólida para escalar:

- simples para implementar agora
- seguro para dados financeiros no nível MVP
- desacoplado de organização, suportando usuários e organizações como donos
- pronto para campanhas sem refatorar o núcleo transacional
- pronto para evolução incremental (mais resiliência, filas, BaaS real)

Você não trava o projeto em complexidade prematura, mas também não cria dívida técnica estrutural.
