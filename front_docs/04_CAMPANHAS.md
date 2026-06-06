# Tela de Campanhas

**Rotas:**
- Listagem: `/campaigns`
- Criar: `/campaigns/new`
- Detalhe: `/campaigns/:id`
- Editar: pendente no backend (futuro)

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/organizations/:id/campaigns` — Listar campanhas
**Query params:** `?limit=100` (opcional, default 100)

**Response:**
```json
[
  {
    "campaign_id": "c001-...",
    "organization_id": "org-...",
    "name": "Festa Junina Beneficente",
    "description": "Arrecadação para a festa junina da comunidade",
    "goal_cents": 1000000,
    "raised_cents": 800000,
    "status": "active",
    "starts_at": "2026-05-01T00:00:00Z",
    "ends_at": "2026-07-01T00:00:00Z",
    "created_at": "2026-04-15T10:00:00Z"
  }
]
```

### POST `/api/v1/organizations/:id/campaigns` — Criar campanha
**Request:**
```json
{
  "campaign": {
    "name": "Festa Junina Beneficente",
    "description": "Arrecadação para a festa junina",
    "goal_cents": 1000000,
    "starts_at": "2026-05-01T00:00:00Z",
    "ends_at": "2026-07-01T00:00:00Z",
    "status": "active"
  }
}
```

**Response (201):**
```json
{
  "campaign_id": "c001-...",
  "organization_id": "org-..."
}
```

### GET `/api/v1/organizations/:id/campaigns/:campaign_id` — Detalhe
**Response:**
```json
{
  "campaign_id": "c001-...",
  "organization_id": "org-...",
  "name": "Festa Junina Beneficente",
  "description": "Arrecadação para a festa junina da comunidade",
  "goal_cents": 1000000,
  "raised_cents": 800000,
  "status": "active",
  "starts_at": "2026-05-01T00:00:00Z",
  "ends_at": "2026-07-01T00:00:00Z",
  "created_at": "2026-04-15T10:00:00Z"
}
```

### GET `/api/v1/campaigns/:campaign_id/transactions` — Transações da campanha
**Query params:** `?limit=50`

**Response:**
```json
[
  {
    "transaction_id": "t001-...",
    "amount_cents": 50000,
    "transaction_type": "credit",
    "status": "captured",
    "created_at": "2026-06-05T14:30:00Z"
  }
]
```

---

## 1. Listagem de Campanhas (`/campaigns`)

```
┌─────────────────────────────────────────────────────────┐
│  Campanhas                                [+ Nova]      │
│                                                     │
│  ┌── Filtros ──────────────────────────────────────┐  │
│  │  [Todos] [Ativas] [Encerradas] [Rascunho]      │  │
│  │  Buscar: [_____________________________]       │  │
│  └────────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Festa Junina        Ativa      Meta: R$ 10.000 │ │
│  │ ████████████░░░░ 80%        Arrec: R$ 8.000   │ │
│  │ 01/05 até 01/07                          👁️    │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Campanha do Agasalho  Ativa    Meta: R$ 5.000  │ │
│  │ ██████░░░░░░░░░░ 60%        Arrec: R$ 3.000   │ │
│  │ 01/04 até 30/06                          👁️    │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ Natal Solidário      Encerrada Meta: R$ 20.000 │ │
│  │ ████████████████ 100%       Arrec: R$ 20.000  │ │
│  │ 01/11 até 31/12                          👁️    │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Card de Campanha (componente)
| Elemento | Fonte | Formatação |
|----------|-------|-----------|
| Nome | `name` | Texto em negrito |
| Status | `status` | Badge colorido: active=verde, ended=cinza, draft=amarelo |
| Meta | `goal_cents` | `R$ 10.000,00` |
| Arrecadado | `raised_cents` | `R$ 8.000,00` |
| Progresso | `raised_cents / goal_cents * 100` | Barra + porcentagem |
| Período | `starts_at` / `ends_at` | `01/05 até 01/07` |
| Ação | 👁️ | Link para `/campaigns/:id` |

### Filtros
| Filtro | Comportamento |
|--------|---------------|
| Abas | "Todos", "Ativas", "Encerradas", "Rascunho" — filtra por `status` |
| Busca | Filtra por `name` contendo o termo (frontend, client-side) |

---

## 2. Formulário de Criar Campanha (`/campaigns/new`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Voltar                              Nova Campanha     │
│                                                     │
│  ┌── Formulário ────────────────────────────────────┐  │
│  │                                                   │  │
│  │  Nome da Campanha *                              │  │
│  │  [__________________________________________]   │  │
│  │                                                   │  │
│  │  Descrição                                       │  │
│  │  [__________________________________________]   │  │
│  │  [__________________________________________]   │  │
│  │                                                   │  │
│  │  Meta de Arrecadação (R$) *                      │  │
│  │  [___________10.000,00___________]               │  │
│  │                                                   │  │
│  │  Data de Início                                  │  │
│  │  [__01/05/2026__] ⌚                              │  │
│  │                                                   │  │
│  │  Data de Término                                 │  │
│  │  [__01/07/2026__] ⌚                              │  │
│  │                                                   │  │
│  │  Status                                           │  │
│  │  [Ativa        ▼]                                │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ [Cancelar]                     [Criar]      │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Campos do Formulário

| Campo | Tipo | Obrigatório | Validações |
|-------|------|-------------|------------|
| `name` | text | Sim | Mín. 3 caracteres |
| `description` | textarea | Não | Máx. 1000 caracteres |
| `goal_cents` | money (cents) | Sim | Mín. R$ 1,00, max. R$ 10.000.000,00 |
| `starts_at` | date | Não | Não pode ser futura demais (opcional) |
| `ends_at` | date | Não | Deve ser após `starts_at` |
| `status` | select | Não | Opções: "active", "draft", "ended" |

### Conversão de Valor
```typescript
// Input exibe: "10.000,00"
// API envia: 1000000 (cents)
function displayToCents(display: string): number {
  return Math.round(parseFloat(display.replace(/\./g, '').replace(',', '.')) * 100);
}

function centsToDisplay(cents: number): string {
  return (cents / 100).toLocaleString('pt-BR', { minimumFractionDigits: 2 });
}
```

---

## 3. Detalhe da Campanha (`/campaigns/:id`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Campanhas                  Festa Junina Beneficente   │
│                                                     │
│  ┌──────┬─────────┬────────┬──────────────────┐       │
│  │ 🎯   │ 💰      │ 💳    │ 📅               │       │
│  │ Meta │ R$ 8.000│ R$ 2.000│ 01/05 a 01/07  │       │
│  │ R$ 10k│ de R$ 10k│ gastos │                  │       │
│  └──────┴─────────┴────────┴──────────────────┘       │
│                                                     │
│  ██████████████░░░░░░░░ 80%                          │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │  [📊 Despesas]  [💳 Transações]  [🔗 Link Público]│ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
│  ┌── Aba ativa: Despesas ──────────────────────────┐ │
│  │                                                   │ │
│  │  Despesas da Campanha              [+ Nova]      │ │
│  │                                                   │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │ R$ 200,00  Buffet            📎 2 anexos   │ │ │
│  │  │ Categoria: Alimentação    05/06/2026       │ │ │
│  │  ├─────────────────────────────────────────────┤ │ │
│  │  │ R$ 150,00  Toldo             📎 1 anexo    │ │ │
│  │  │ Categoria: Estrutura      01/06/2026       │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────┘ │
│                                                     │
│  ┌── Aba ativa: Transações ────────────────────────┐ │
│  │                                                   │ │
│  │  +R$ 500,00  Doação online       05/06 14:30    │ │
│  │  +R$ 150,00  Doação PIX          05/06 10:00    │ │
│  │  +R$ 50,00   Doação cartão       04/06 18:00    │ │
│  └──────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Abas do Detalhe

| Aba | Conteúdo | Endpoint |
|-----|----------|----------|
| **Despesas** | Lista de despesas da campanha | `GET /org/:id/campaigns/:cid/expenses` |
| **Transações** | Lista de transações da campanha | `GET /campaigns/:cid/transactions` |
| **Link Público** | Link para página pública de doação | `/public/donate/:campaign_id` |

### Botão "Link Público"
Gera URL: `https://clareo.app/public/donate/:campaign_id`
- Botão "Copiar link" para compartilhar
- QR Code (opcional, implementação futura)

---

## Dados no Frontend

```typescript
// Cache com React Query
const useCampaigns = (orgId: string) => ({
  queryKey: ['campaigns', orgId],
  queryFn: () => fetch(`/api/v1/organizations/${orgId}/campaigns?limit=100`)
});

const useCampaign = (orgId: string, campaignId: string) => ({
  queryKey: ['campaigns', orgId, campaignId],
  queryFn: () => fetch(`/api/v1/organizations/${orgId}/campaigns/${campaignId}`)
});
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Lista campanhas | 30s | Ao criar/editar campanha |
| Detalhe campanha | 30s | Pull-to-refresh |
| Transações da campanha | 30s | Automático |
