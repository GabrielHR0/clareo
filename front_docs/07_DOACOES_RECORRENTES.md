# Tela de Doações Recorrentes

**Rotas:**
- Listagem por contribuinte: `/contributors/:id/recurring`
- Criar: `/contributors/:id/recurring/new`
- **Obs:** Esta tela é geralmente acessada como seção dentro do Detalhe do Contribuinte

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/contributors/:contributor_id/recurring_donations` — Listar
**Response:**
```json
[
  {
    "recurring_id": "rec-001-...",
    "organization_id": "org-...",
    "contributor_id": "ctb-001-...",
    "amount_cents": 5000,
    "interval_days": 30,
    "payment_method": "card",
    "card_reference": "card_...",
    "status": "active",
    "next_charge_date": "2026-07-05",
    "campaign_id": "c001-...",
    "created_at": "2026-05-01T10:00:00Z"
  }
]
```

### POST `/api/v1/contributors/:contributor_id/recurring_donations` — Criar
**Request:**
```json
{
  "recurring_donation": {
    "organization_id": "org-...",
    "amount_cents": 5000,
    "currency": "BRL",
    "payment_method": "card",
    "card_reference": "card_...",
    "interval_days": 30,
    "campaign_id": "c001-...",
    "next_charge_date": "2026-07-05"
  }
}
```

**Response (201):**
```json
{
  "recurring_id": "rec-001-...",
  "organization_id": "org-...",
  "contributor_id": "ctb-001-..."
}
```

### PATCH `/api/v1/contributors/:contributor_id/recurring_donations/:id` — Cancelar
**Request:**
```json
{
  "organization_id": "org-..."
}
```

**Response:** `200 OK` (sem corpo)

### DELETE `/api/v1/contributors/:contributor_id/recurring_donations/:id` — Cancelar (alternativo)
**Request:**
```json
{
  "organization_id": "org-..."
}
```

**Response:** `200 OK` (sem corpo)

> **Nota:** Tanto PATCH quanto DELETE apenas cancelam a doação (mudam status para "cancelled"), não removem o registro.

---

## 1. Listagem de Doações Recorrentes

Exibida dentro do Detalhe do Contribuinte ou como página standalone.

```
┌─────────────────────────────────────────────────────────┐
│  ← João Silva          Doações Recorrentes              │
│                                                     │
│  Total ativo: R$ 80,00/mês em 2 assinaturas          │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Festa Junina            R$ 50,00/mês   Ativo   │ │
│  │ 📅 Próxima: 05/07/2026  💳 Cartão       [🛑]  │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Campanha Agasalho       R$ 30,00/mês   Ativo   │ │
│  │ 📅 Próxima: 12/07/2026  💳 Cartão       [🛑]  │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Natal Solidário         R$ 20,00/mês  Cancelada│ │
│  │ Cancelada em 01/06/2026                        │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
│  [Nova Doação Recorrente]                            │
└─────────────────────────────────────────────────────────┘
```

### Card de Doação Recorrente
| Elemento | Fonte |
|----------|-------|
| Nome da campanha | `campaign_id` → lookup nome |
| Valor | `amount_cents` formatado + "/mês" |
| Status | `status` (active=verde, cancelled=cinza) |
| Próxima cobrança | `next_charge_date` |
| Método | `payment_method` (card, pix, boleto) |
| Botão 🛑 Cancelar | Modal de confirmação → `PATCH` |

---

## 2. Formulário de Nova Doação Recorrente

```
┌─────────────────────────────────────────────────────────┐
│  ← Doações Recorrentes     Nova Assinatura              │
│                                                     │
│  ┌── Formulário ────────────────────────────────────┐  │
│  │                                                   │  │
│  │  Campanha                                        │  │
│  │  [Festa Junina Beneficente          ▼]           │  │
│  │                                                   │  │
│  │  Valor Mensal (R$) *                             │  │
│  │  [___________50,00_______________]               │  │
│  │                                                   │  │
│  │  Intervalo                                       │  │
│  │  [Mensal (30 dias)              ▼]               │  │
│  │                                                   │  │
│  │  Método de Pagamento                             │  │
│  │  [Cartão de Crédito            ▼]               │  │
│  │                                                   │  │
│  │  Referência do Cartão                            │  │
│  │  [Cartão final 1234          ▼]                 │  │
│  │                                                   │  │
│  │  Data da Primeira Cobrança                       │  │
│  │  [__05/07/2026__] ⌚                              │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ [Cancelar]                     [Criar]      │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Campos
| Campo | Tipo | Obrigatório | Observação |
|-------|------|-------------|------------|
| `campaign_id` | select (campanhas) | Não | Carregar lista de campanhas da org |
| `amount_cents` | money | Sim | Mín. R$ 1,00 |
| `interval_days` | select | Não | 7 (semanal), 15 (quinzenal), 30 (mensal), 90 (trimestral) |
| `payment_method` | select | Não | card, pix, boleto |
| `card_reference` | select | Se `payment_method=card` | Carregar cartões salvos |
| `next_charge_date` | date | Não | Padrão: data atual + interval_days |

---

## 3. Modal de Cancelamento

```
┌─────────────────────────────────────┐
│  Cancelar Doação Recorrente         │
│                                     │
│  Tem certeza que deseja cancelar    │
│  a doação de R$ 50,00/mês para      │
│  a campanha Festa Junina?           │
│                                     │
│  [Não]  [Sim, Cancelar]             │
└─────────────────────────────────────┘
```

| Ação | Resultado |
|------|-----------|
| "Sim, Cancelar" | `PATCH .../recurring_donations/:id` → atualiza status |
| "Não" | Fecha modal |

---

## Dados do Frontend

```typescript
const useRecurringDonations = (contributorId: string) => ({
  queryKey: ['recurring', contributorId],
  queryFn: () => fetch(`/api/v1/contributors/${contributorId}/recurring_donations`)
});

const useCampaigns = (orgId: string) => ({
  // Carregar para preencher select de campanhas
});
```

### Cálculos
```typescript
// Total mensal ativo
const totalActive = donations
  .filter(d => d.status === 'active')
  .reduce((sum, d) => sum + d.amount_cents, 0);
// Exibe: "R$ 80,00/mês"
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Lista doações | 30s | Após criar/cancelar |
| Campanhas (select) | 1 min | Manual |
| Métodos pagamento | 5 min | Manual |
