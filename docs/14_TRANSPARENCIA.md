# Plano de Transparência e Prestação de Contas

## Filosofia

> "A transparência não é um recurso, é um princípio fundacional."

Cada centavo doado deve ser rastreável desde o contribuidor até o destino final. A plataforma deve permitir que qualquer pessoa — mesmo sem cadastro — veja como os recursos estão sendo alocados.

---

## Pilares da Transparência

```
         TRANSPARÊNCIA
    ┌──────┼──────┐
    |      |      |
  Rastreabilidade  Prestação  Alocação
  (imutável)    de Contas  (programas)
```

---

## Fase 1 — Rastreabilidade (já existe)

### ✅ O que já temos
| Funcionalidade | Status |
|---------------|--------|
| `transactions_by_owner` — histórico completo por entidade | ✅ |
| `ledger_entries_by_owner` — partidas dobradas imutáveis | ✅ |
| `audit_events` — log de auditoria imutável | ✅ |
| Idempotência — cada transação tem chave única | ✅ |
| Concorrência — optimistic locking com versão | ✅ |

### 📌 O que falta
| Item | Prioridade |
|------|-----------|
| **Link público de rastreamento** — qualquer pessoa consultar uma doação pelo ID | 🔴 |
| **Proof of Reserve** — hash do ledger publicado periodicamente | 🟡 |
| **Reconciliação automática** — soma dos ledgers = saldo das wallets | 🟡 |

---

## Fase 2 — API Pública de Transparência

### Endpoints Públicos (sem autenticação)

```ruby
# config/routes.rb
scope "/api/v1/public" do
  get "/organizations/:id" => "public#organization_summary"
  get "/organizations/:id/transactions" => "public#organization_transactions"
  get "/organizations/:id/ledger" => "public#organization_ledger"
  get "/organizations/:id/campaigns" => "public#organization_campaigns"
  get "/transactions/:id" => "public#transaction_detail"
end
```

### 2.1 Resumo Público da Organização

```json
GET /api/v1/public/organizations/:id
{
  "organization": {
    "name": "Instituição ABC",
    "legal_name": "ABC Ltda",
    "document": "12.345.678/0001-90"
  },
  "metrics": {
    "total_raised_cents": 15000000,
    "total_raised_formatted": "R$ 150.000,00",
    "total_donors": 342,
    "active_campaigns": 3,
    "monthly_recurring_cents": 450000,
    "last_donation_at": "2026-06-01T10:30:00Z"
  },
  "allocation": {
    "programs": [
      { "name": "Alimentação", "percentage": 40, "amount_cents": 6000000 },
      { "name": "Educação", "percentage": 35, "amount_cents": 5250000 },
      { "name": "Administrativo", "percentage": 25, "amount_cents": 3750000 }
    ]
  }
}
```

### 2.2 Transações da Organização (últimas 50)

```json
GET /api/v1/public/organizations/:id/transactions
[
  {
    "transaction_id": "uuid",
    "type": "credit",
    "amount_cents": 5000,
    "amount_formatted": "R$ 50,00",
    "description": "Doação anônima para Campanha Natal",
    "status": "captured",
    "created_at": "2026-06-01T10:30:00Z"
  }
]
```

### 2.3 Detalhe da Transação

```json
GET /api/v1/public/transactions/:id
{
  "transaction": { ... },
  "ledger_entries": [
    { "account": "donations", "entry_type": "credit", "amount_cents": 5000 },
    { "account": "cash", "entry_type": "debit", "amount_cents": 5000 }
  ],
  "audit_events": [
    { "event_type": "payment_authorized_by_gateway", "created_at": "..." },
    { "event_type": "wallet_credited", "created_at": "..." }
  ]
}
```

### TDD Specs
- Resumo público retorna métricas sem expor dados sensíveis
- Transações públicas não expõem `api_key_hash` ou `webhook_url`
- Consulta de organização inexistente → 404
- Transação pública contém entradas de ledger
- Contribuidor pode opt-out (anônimo)

---

## Fase 3 — Alocação de Recursos

### 3.1 Programas/Projetos

Nova tabela para alocação:

```cql
CREATE TABLE IF NOT EXISTS clareo.allocation_programs (
    organization_id uuid,
    program_id uuid,
    name text,
    description text,
    percentage int,                -- % da receita alocada (ex: 40)
    category text,                 -- operational | program | reserve
    active boolean,
    created_at timestamp,
    updated_at timestamp,
    PRIMARY KEY ((organization_id), program_id)
);
```

**Endpoints protegidos (requer API Key da org):**
| Método | Rota |
|--------|------|
| POST | `/api/v1/organizations/:id/programs` |
| GET | `/api/v1/organizations/:id/programs` |
| PATCH | `/api/v1/programs/:id` |

### 3.2 Relatório de Alocação

Serviço que calcula quanto de cada doação foi para cada programa:

```ruby
class AllocationReportService
  def self.generate(organization_id, start_date, end_date)
    transactions = TransactionsByOwnerRepository
      .find_by_owner(organization_id, "organization", 10000)
      .select { |t| t[:created_at].between?(start_date, end_date) }

    programs = AllocationProgramRepository.find_by_organization(organization_id)
    total = transactions.sum { |t| t[:amount_cents] }

    programs.map do |prog|
      allocated = (total * prog[:percentage] / 100.0).round
      {
        program: prog[:name],
        percentage: prog[:percentage],
        allocated_cents: allocated,
        allocated_formatted: "R$ #{'%.2f' % (allocated / 100.0)}"
      }
    end
  end
end
```

### TDD Specs
- Criar programa com porcentagens somando 100% → 201
- Criar programa com porcentagens somando >100% → 422
- Relatório de alocação para período → valores corretos
- Relatório com transações filtradas por campanha

---

## Fase 4 — Dashboard de Transparência

### 4.1 JSON estático para alimentar frontend

```json
GET /api/v1/public/organizations/:id/dashboard.json
{
  "organization": { ... },
  "raised": { "total": 15000000, "this_month": 2500000 },
  "donors": { "total": 342, "new_this_month": 15 },
  "recurring": { "active": 89, "monthly_total_cents": 450000 },
  "campaigns": [
    { "name": "Natal 2026", "goal": 5000000, "raised": 3200000, "progress_pct": 64 }
  ],
  "allocation": [ ... ],
  "recent_transactions": [ ... ],
  "ledger_summary": {
    "total_credits": 15000000,
    "total_debits": 4200000,
    "current_balance": 10800000
  }
}
```

### 4.2 Badge de Transparência

Selo embedável que organizações podem colocar em seus sites:

```html
<!-- Código embed -->
<iframe src="https://clareo.app/transparency/badge/ORG_ID"
        width="300" height="400" frameborder="0"></iframe>
```

### TDD Specs
- Dashboard JSON contém todos os campos obrigatórios
- Badge embedable retorna HTML válido
- Cache de 5 minutos para dashboard (evitar sobrecarga no Cassandra)

---

## Fase 5 — Recibos e Relatórios

### 5.1 Recibo de Doação (PDF)

```ruby
class DonationReceiptService
  def self.generate(transaction_id)
    tx = TransactionsByOwnerRepository.find_by_transaction_id(transaction_id)
    org = OrganizationsRepository.find(tx[:owner_id])
    # Gerar PDF com:
    # - Nome da organização (CNPJ)
    # - Nome do contribuidor (CPF)
    # - Valor, data, forma de pagamento
    # - Código de verificação (hash da transação)
    # - QR Code com link de verificação
  end
end
```

### 5.2 Relatório Gerencial Mensal

Serviço que compila:
- Total recebido vs meta
- Top contribuidores
- Crescimento mês a mês
- Taxa de retenção de recorrentes
- Alocação por programa

### TDD Specs
- Recibo gerado com dados corretos
- Código de verificação no recibo é validável
- Relatório mensal soma corretamente
- Relatório mensal com zero transações → vazio (não quebra)
