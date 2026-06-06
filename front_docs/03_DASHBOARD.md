# Tela de Dashboard

**Rota:** `/dashboard`
**Público:** Não (requer `X-API-Key`)
**Objetivo:** Visão geral da organização com métricas consolidadas, campanhas ativas e transações recentes.

---

## Endpoints Utilizados

### GET `/api/v1/organizations/:id/dashboard`
**Header:** `X-API-Key: <api_key>`

**Response (200):**
```json
{
  "organization_id": "a1b2c3d4-...",
  "name": "Instituto Vida",
  "metrics": {
    "total_raised_cents": 1500000,
    "total_spent_cents": 450000,
    "balance_cents": 1050000,
    "wallet_available_cents": 980000,
    "active_campaigns": 3,
    "total_campaigns": 5,
    "member_count": 47,
    "credit_line_available_cents": 500000
  },
  "campaigns": [
    {
      "campaign_id": "c001-...",
      "name": "Festa Junina Beneficente",
      "status": "active",
      "raised_cents": 800000,
      "spent_cents": 200000,
      "balance_cents": 600000,
      "goal_cents": 1000000,
      "progress_pct": 80.0
    },
    {
      "campaign_id": "c002-...",
      "name": "Campanha do Agasalho",
      "status": "active",
      "raised_cents": 300000,
      "spent_cents": 50000,
      "balance_cents": 250000,
      "goal_cents": 500000,
      "progress_pct": 60.0
    }
  ],
  "recent_transactions": [
    {
      "transaction_id": "t001-...",
      "amount_cents": 50000,
      "transaction_type": "credit",
      "status": "captured",
      "campaign_id": "c001-...",
      "created_at": "2026-06-05T14:30:00Z"
    }
  ]
}
```

### GET `/api/v1/organizations/:id` — Dados da organização
**Header:** `X-API-Key: <api_key>`

**Response:**
```json
{
  "id": "a1b2c3d4-...",
  "name": "Instituto Vida",
  "external_id": null,
  "created_at": "2026-01-15T10:00:00Z"
}
```

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│  🏢 Instituto Vida                          ⚙️ Config  │
│                                                     │
│  ┌──────┬─────────┬────────┬──────────────────┐       │
│  │ 💰   │ 📊     │ 🎯    │ 👥               │       │
│  │ R$ 9.800,00  │ R$ 15.000,00  │ 80% 3/5 │ 47 membros  │
│  │ Disponível  │ Arrecadado   │ metas  │              │
│  └──────┴─────────┴────────┴──────────────────┘       │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Campanhas Ativas                    [+ Nova]    │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Festa Junina        ████████████░░ 80%  R$ 8k │ │
│  │ Campanha Agasalho   ██████░░░░░░░░ 60%  R$ 3k │ │
│  │ Natal Solidário     ██░░░░░░░░░░░░ 20%  R$ 1k │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Transações Recentes                  [Ver mais] │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ +R$ 500,00  Festa Junina           há 2 min    │ │
│  │ +R$ 150,00  Campanha Agasalho      há 15 min   │ │
│  │ +R$ 50,00   Natal Solidário        há 1h       │ │
│  │ -R$ 200,00  Despesa (Festa Junina) há 3h       │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Componentes / Seções

### 1. Header
- Nome da organização (vindo do `localStorage` ou do GET organization)
- Ícone de configurações (link para `/settings`)

### 2. Cards de Métricas (4 cards lado a lado)

| Card | Dado | Formatação | Ícone |
|------|------|-----------|-------|
| Saldo Disponível | `metrics.wallet_available_cents` | `R$ 9.800,00` (verde) | 💰 |
| Total Arrecadado | `metrics.total_raised_cents` | `R$ 15.000,00` | 📊 |
| Progresso Campanhas | `active_campaigns / total_campaigns` | `80% (3/5)` | 🎯 |
| Membros | `metrics.member_count` | `47 membros` | 👥 |

### 3. Lista de Campanhas
- **Título:** "Campanhas Ativas" + botão "+ Nova" (link para `/campaigns/new`)
- **Cada item:**
  - Nome da campanha (link para `/campaigns/:id`)
  - Barra de progresso (`progress_pct`)
  - Valor arrecadado (`raised_cents`) vs meta (`goal_cents`)
- **Ordenação:** Por `progress_pct` decrescente ou por `raised_cents`
- **Filtro:** Mostrar apenas campanhas com `status = "active"`

### 4. Transações Recentes
- **Título:** "Transações Recentes" + link "Ver mais" (para `/transactions`)
- **Cada item:**
  - Ícone de `+` (crédito) ou `-` (débito)
  - Valor formatado: `R$ 500,00`
  - Nome da campanha (se tiver `campaign_id`)
  - Timestamp relativo: "há 2 min", "há 15 min"
- **Ordenação:** Por `created_at` decrescente
- **Limite:** Últimas 5 transações

---

## Estados da Tela

### Carregando
```typescript
// Mostrar skeleton loader (4 cards pulando, lista com linhas cinzas)
```

### Erro — API Key inválida
```typescript
// Redirecionar para /login com mensagem "Chave de acesso inválida"
```

### Erro — Rede
```typescript
// Toast/Banner: "Erro de conexão. Verifique sua internet."
// Botão: "Tentar novamente"
```

### Vazio (organização nova, sem dados)
```typescript
// Cards mostram R$ 0,00
// Campanhas: "Nenhuma campanha ainda. Crie sua primeira campanha!"
// Transações: "Nenhuma transação recente."
```

---

## Cálculos de Display

```typescript
function formatCents(cents: number): string {
  return `R$ ${(cents / 100).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
}

function relativeTime(isoDate: string): string {
  // "há 2 min", "há 15 min", "há 1h", "há 3h", "ontem", "há 2 dias"
}

function progressBar(pct: number): string {
  // Retorna largura em % para a barra de progresso CSS
  return `${Math.min(pct, 100)}%`;
}
```

---

## Cache e Refetch

| Dado | Cache | Refetch |
|------|-------|---------|
| Dashboard | 30 segundos | Pull-to-refresh + automático |
| Organização | 5 minutos | Ao salvar configurações |
