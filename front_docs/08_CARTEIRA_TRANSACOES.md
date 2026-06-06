# Tela de Carteira e Transações

**Rotas:**
- Carteira: `/wallet`
- Transações: `/transactions`
- Detalhe da transação: `/transactions/:id`

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/owners/organization/:org_id/wallet` — Saldo da carteira
**Header:** `X-API-Key: <api_key>`

**Response:**
```json
{
  "owner_type": "organization",
  "owner_id": "org-...",
  "balance_cents": 1050000,
  "available_cents": 980000,
  "locked_cents": 70000,
  "version": 42,
  "created_at": "2026-01-15T10:00:00Z",
  "updated_at": "2026-06-05T14:30:00Z"
}
```

### GET `/api/v1/owners/organization/:org_id/transactions` — Listar transações
**Query params:** `?limit=100` (default 100, max 1000)

**Response:**
```json
[
  {
    "transaction_id": "t001-...",
    "owner_type": "organization",
    "owner_id": "org-...",
    "amount_cents": 50000,
    "currency": "BRL",
    "transaction_type": "credit",
    "status": "captured",
    "campaign_id": "c001-...",
    "idempotency_key": "ext_abc123",
    "external_reference": null,
    "metadata": null,
    "created_at": "2026-06-05T14:30:00Z"
  }
]
```

### GET `/api/v1/owners/organization/:org_id/transactions/:id` — Detalhe da transação
**Filtros disponíveis:** por campanha, por tipo, por data.

### GET `/api/v1/campaigns/:campaign_id/transactions` — Transações por campanha
**Query params:** `?limit=50`
Usado na aba de transações do detalhe da campanha.

---

## Layout da Tela (`/wallet`)

```
┌─────────────────────────────────────────────────────────┐
│  Carteira e Transações                   🏦             │
│                                                     │
│  ┌────────────────────────────────────────────────┐    │
│  │  Saldo Total        Disponível      Bloqueado  │    │
│  │  R$ 10.500,00       R$ 9.800,00   R$ 700,00   │    │
│  │                                            │    │
│  │  [Ver Extrato] →                               │    │
│  └────────────────────────────────────────────────┘    │
│                                                     │
│  ┌── Gráfico de Entradas vs Saídas (últimos 30d) ──┐ │
│  │                                                   │ │
│  │  ██████████████████████████████████████           │ │
│  │  ██████████████████████████████████████           │ │
│  │  ██████████████████████░░░░░░░░░░░░░░░           │ │
│  │  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░           │ │
│  │  └───┬───┬───┬───┬───┬───┬───┬───┬───           │ │
│  │      05/06  06/06  07/06  08/06  ...             │ │
│  │    █ Entradas   ░ Saídas                         │ │
│  └──────────────────────────────────────────────────┘ │
│                                                     │
│  ┌── Ações Rápidas ───────────────────────────────┐  │
│  │  [➡️ Transferir] [💳 Adicionar Fundos]         │  │
│  └──────────────────────────────────────────────────┘ │
│                                                     │
│  ┌── Últimas Transações ──────────────────────────┐  │
│  │  [Filtros]                                     │  │
│  │  ┌───────────────────────────────────────────┐ │  │
│  │  │ + R$ 500,00  Festa Junina   Doação  📅 hoj│ │  │
│  │  │ + R$ 150,00  Camp. Agasalho Doação  📅 hoje│ │  │
│  │  │ - R$ 200,00  Festa Junina   Despesa 📅 ontem│ │  │
│  │  └───────────────────────────────────────────┘ │  │
│  │  [Ver todas as transações]                      │  │
│  └──────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Cards de Saldo
| Card | Dado | Cor |
|------|------|-----|
| Saldo Total | `balance_cents` | Azul |
| Disponível | `available_cents` | Verde |
| Bloqueado | `locked_cents` | Laranja |

---

## Tela de Transações (`/transactions`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Carteira                 Transações                   │
│                                                     │
│  ┌── Filtros ──────────────────────────────────────┐   │
│  │                                                   │   │
│  │  Período: [Últimos 30 dias         ▼]           │   │
│  │  Tipo:    [Todos                    ▼]           │   │
│  │  Status:  [Todos                    ▼]           │   │
│  │  Campanha:[Todas                    ▼]           │   │
│  │                                                   │   │
│  │  Buscar: [_____________________________]         │   │
│  │                                                   │   │
│  │  Resultados: 45 transações                       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Tabela ──────────────────────────────────────┐   │
│  │ Data       │ Descrição         │ Valor   │      │   │
│  ├────────────────────────────────────────────────┤   │
│  │ 05/06 14:30│ Festa Junina      │ +R$ 500 │ 🟢  │   │
│  │ 05/06 10:00│ Camp. Agasalho    │ +R$ 150 │ 🟢  │   │
│  │ 04/06 18:00│ Buffet (F. Junina)│ -R$ 200 │ 🔴  │   │
│  │ 04/06 09:00│ Pagamento Crédito │ -R$ 300 │ 🔴  │   │
│  │ 03/06 15:00│ Doação PIX        │ +R$ 1000│ 🟢  │   │
│  └────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Paginação ────────────────────────────────────┐  │
│  │  [<]  1  2  3  4  5  ...  10  [>]              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Filtros da Tabela
| Filtro | Tipo | Opções |
|--------|------|--------|
| Período | select | Hoje, Últimos 7 dias, Últimos 30 dias, Este mês, Personalizado |
| Tipo | select | Todos, credit, debit, transfer, external_in, external_out, withdrawal |
| Status | select | Todos, authorized, captured, refunded, failed, reversed |
| Campanha | select | Todas + lista de campanhas da org |
| Busca | text | Filtra por `idempotency_key` ou `external_reference` |

### Colunas da Tabela
| Coluna | Fonte | Formatação |
|--------|-------|-----------|
| Data | `created_at` | `05/06 14:30` |
| Descrição | `campaign_id` → nome | Se não tem campanha: tipo da transação |
| Valor | `amount_cents` | `+R$ 500,00` (verde) / `-R$ 200,00` (vermelho) |
| Status | `status` | Badge: captured=🟢, failed=🔴, ... |
| Ação | 👁️ | Link para `/transactions/:id` |

---

## Detalhe da Transação (`/transactions/:id`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Transações             Detalhe da Transação           │
│                                                     │
│  ┌── Informações ──────────────────────────────────┐   │
│  │                                                   │   │
│  │  ID:          t001-...                           │   │
│  │  Tipo:        💳 Crédito (Doação)                 │   │
│  │  Valor:       R$ 500,00                           │   │
│  │  Status:      ✅ Capturada                        │   │
│  │  Campanha:    Festa Junina                        │   │
│  │  Data:        05/06/2026 às 14:30                │   │
│  │  Chave Idemp.: ext_abc123                        │   │
│  │                                                   │   │
│  │  ┌─────────────────────────────────────────────┐ │   │
│  │  │ 📄 Comprovante (PDF)                       │ │   │
│  │  └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Informações Exibidas
| Campo | Fonte |
|-------|-------|
| ID | `transaction_id` |
| Tipo | `transaction_type` formatado (credit→"Crédito", debit→"Débito", etc) |
| Valor | `amount_cents` com sinal |
| Status | `status` com label em português |
| Campanha | `campaign_id` → lookup nome (se existir) |
| Data | `created_at` formatado |
| Chave Idempotência | `idempotency_key` (se existir) |
| Ref. Externa | `external_reference` (se existir) |

---

## Transferência entre Carteiras

**Endpoint:** `POST /api/v1/owners/organization/:org_id/transactions`

Para criar uma transferência:
```json
{
  "transaction": {
    "amount_cents": 50000,
    "transaction_type": "transfer",
    "idempotency_key": "transfer_001",
    "dest_owner_type": "contributor",
    "dest_owner_id": "ctb-001-..."
  }
}
```

**Response:**
```json
{
  "status": "ok",
  "transaction_id": "t001-...",
  "transfer_id": "t002-...",
  "provider_reference": "ref_..."
}
```

**Formulário de Transferência (modal):**
```
┌───────────────────────────────────────────────┐
│  Transferir                                    │
│                                               │
│  De: Instituto Vida                           │
│                                               │
│  Para: [Selecionar contribuinte ▼]           │
│                                               │
│  Valor (R$): [________500,00________]        │
│                                               │
│  Descrição: [________________________]       │
│                                               │
│  [Cancelar]  [Transferir]                    │
└───────────────────────────────────────────────┘
```

---

## Dados do Frontend

```typescript
const useWallet = (orgId: string) => ({
  queryKey: ['wallet', orgId],
  queryFn: () => fetch(`/api/v1/owners/organization/${orgId}/wallet`)
});

const useTransactions = (orgId: string, params: TransactionFilters) => ({
  queryKey: ['transactions', orgId, params],
  queryFn: () => {
    const query = new URLSearchParams({ limit: '100', ...params });
    return fetch(`/api/v1/owners/organization/${orgId}/transactions?${query}`);
  }
});
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Saldo carteira | 15s | Automático |
| Lista transações | 30s | Ao filtrar/navegar |
| Detalhe transação | 1 min | Manual |
