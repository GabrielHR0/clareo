# Clareo

**Banking as a Service API** — Gestão de doações, campanhas, carteiras e transparência financeira para organizações.

Stack: **Rails 8 + Cassandra 4.1 + Redis + Sidekiq**

---

## Documentação da API

### Swagger / OpenAPI

Interativo: http://localhost:3000/api-docs  
JSON: http://localhost:3000/api-docs/swagger.json

---

## Autenticação

O sistema tem dois métodos de autenticação:

| Método | Header | Uso |
|--------|--------|-----|
| **JWT** | `Authorization: Bearer <token>` | Frontend web (usuários) |
| **API Key** | `X-API-Key: <chave>` | Integrações externas |

### Fluxo de cadastro e login

```
POST /api/v1/auth/register   → 201 { user, token }   # Criar conta
POST /api/v1/auth/login      → 200 { user, token }   # Login
GET  /api/v1/auth/me         → 200 { user }          # Dados do usuário logado
```

### Criação de organização (autenticado com JWT)

```
POST /api/v1/organizations   → 201 { organization, api_key, wallet }
```

### Rotas públicas (sem auth)

| Rota | Descrição |
|------|-----------|
| `GET /up` | Health check Rails |
| `GET /health/cassandra` | Health check Cassandra |
| `GET /health/redis` | Health check Redis |
| `GET /health/all` | Health check combinado |
| `GET /api-docs/*` | Swagger UI |
| `POST /api/v1/public/checkout` | Doação pública |
| `GET /api/v1/public/campaigns/:id/accountability` | Prestação de contas |
| `POST /api/v1/auth/register` | Cadastro de usuário |
| `POST /api/v1/auth/login` | Login |

---

## Rotas da API (v1)

Todas as rotas estão disponíveis com e sem o prefixo `/api/v1`.

### Organizations

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/organizations` | Listar organizações |
| `POST` | `/organizations` | Criar organização (gera API Key) |
| `GET` | `/organizations/:id` | Detalhe da organização |

### Campaigns

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/organizations/:org_id/campaigns` | Listar campanhas |
| `POST` | `/organizations/:org_id/campaigns` | Criar campanha |
| `GET` | `/organizations/:org_id/campaigns/:id` | Detalhe da campanha |

### Expenses

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/organizations/:org_id/campaigns/:camp_id/expenses` | Listar despesas |
| `POST` | `/organizations/:org_id/campaigns/:camp_id/expenses` | Criar despesa |
| `GET` | `/organizations/:org_id/campaigns/:camp_id/expenses/:id` | Detalhe da despesa |
| `PATCH` | `/organizations/:org_id/campaigns/:camp_id/expenses/:id` | Atualizar despesa |
| `DELETE` | `/organizations/:org_id/campaigns/:camp_id/expenses/:id` | Excluir despesa |

### Expense Attachments

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/organizations/:org_id/campaigns/:camp_id/expenses/:exp_id/attachments` | Anexar arquivo |
| `GET` | `/organizations/:org_id/campaigns/:camp_id/expenses/:exp_id/attachments/:id/download` | Download do anexo |
| `DELETE` | `/organizations/:org_id/campaigns/:camp_id/expenses/:exp_id/attachments/:id` | Remover anexo |

### Contributors

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/contributors` | Listar contribuintes |
| `POST` | `/contributors` | Criar contribuinte |
| `GET` | `/contributors/:id` | Detalhe do contribuinte |

### Recurring Donations

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/contributors/:id/recurring_donations` | Listar doações recorrentes |
| `POST` | `/contributors/:id/recurring_donations` | Criar doação recorrente |
| `PATCH` | `/contributors/:id/recurring_donations/:rec_id` | Cancelar |
| `DELETE` | `/contributors/:id/recurring_donations/:rec_id` | Cancelar |

### Memberships

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/memberships` | Listar vínculos |
| `POST` | `/memberships` | Criar vínculo |

### Wallets

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/owners/:owner_type/:owner_id/wallet` | Saldo da carteira |

### Transactions

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/owners/:owner_type/:owner_id/transactions` | Criar transação |
| `GET` | `/owners/:owner_type/:owner_id/transactions` | Listar transações |
| `GET` | `/owners/:owner_type/:owner_id/transactions/:id` | Detalhe da transação |
| `GET` | `/campaigns/:campaign_id/transactions` | Transações por campanha |

### Payment Methods

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/owners/:owner_type/:owner_id/payment_methods` | Adicionar método |

### Credit Lines

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/credit_lines` | Listar linhas de crédito |
| `POST` | `/credit_lines` | Contratar linha |
| `GET` | `/credit_lines/:id` | Detalhe da linha |
| `POST` | `/credit_lines/:id/use` | Sacar da linha |

### Dashboard

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/organizations/:id/dashboard` | Dashboard com métricas |

### Públicas

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/public/checkout` | Processar doação |
| `GET` | `/public/campaigns/:campaign_id/accountability` | Prestação de contas |

---

## Desenvolvimento Local

```bash
docker compose up -d
```

### Serviços

| Serviço | Porta |
|---------|-------|
| Rails API | 3000 |
| Cassandra | 9042 |
| Redis | 6379 |
| Sidekiq | — (background) |

### Migrations (rodam automático no entrypoint)

```bash
docker exec clareo-rails-1 bin/rails cassandra:migrate
```

### Testes

```bash
docker exec clareo-rails-1 bundle exec rspec
```

---

## Modelo de Dados

Tabelas no Cassandra (keyspace `clareo`):

- `organizations` — Organizações com API Key (hash SHA-256)
- `users` — Usuários com email e senha (bcrypt)
- `contributors` — Contribuintes (doadores)
- `campaigns` — Campanhas de arrecadação
- `expense_entries` — Despesas de campanhas
- `expense_attachments` — Anexos de despesas
- `wallets` — Carteiras (saldo, optimistic locking)
- `transactions_by_owner` — Transações financeiras
- `transactions_by_campaign` — Transações por campanha
- `ledger_entries_by_owner` — Partidas dobradas (auditoria)
- `memberships_by_organization` — Vínculos org↔contribuidor
- `memberships_by_contributor` — Vínculos por contribuidor
- `recurring_donations` — Doações recorrentes
- `payment_methods` — Métodos de pagamento
- `credit_lines` — Linhas de crédito
- `payment_intents_by_owner` — Intents de pagamento
- `idempotency_keys_by_owner` — Chaves de idempotência
- `audit_events` — Eventos de auditoria

---

## Frontend Docs

→ [front_docs/](front_docs/) — Especificações de telas, endpoints e dados.

---

## Deploy (k3s)

→ [INSTRUCTIONS.md](INSTRUCTIONS.md) — Guia completo de deploy no Kubernetes.
