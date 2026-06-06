# Tela de Linhas de Crédito

**Rotas:**
- Listagem: `/credit-lines`
- Criar: `/credit-lines/new`
- Detalhe/Uso: `/credit-lines/:id`

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/credit_lines?organization_id=:org_id` — Listar linhas de crédito
**Header:** `X-API-Key: <api_key>`

**Response:**
```json
[
  {
    "credit_line_id": "cl-001-...",
    "organization_id": "org-...",
    "limit_cents": 500000,
    "available_cents": 350000,
    "used_cents": 150000,
    "annual_rate": 12.5,
    "status": "active",
    "created_at": "2026-03-01T10:00:00Z"
  }
]
```

### POST `/api/v1/credit_lines` — Contratar linha de crédito
**Request:**
```json
{
  "credit_line": {
    "organization_id": "org-...",
    "limit_cents": 500000,
    "annual_rate": 12.5
  }
}
```

**Response (201):**
```json
{
  "credit_line_id": "cl-001-...",
  "organization_id": "org-...",
  "limit_cents": 500000,
  "available_cents": 500000,
  "annual_rate": 12.5,
  "status": "active"
}
```

### GET `/api/v1/credit_lines/:id` — Detalhe
**Response:**
```json
{
  "credit_line_id": "cl-001-...",
  "organization_id": "org-...",
  "limit_cents": 500000,
  "available_cents": 350000,
  "used_cents": 150000,
  "annual_rate": 12.5,
  "status": "active",
  "created_at": "2026-03-01T10:00:00Z"
}
```

### POST `/api/v1/credit_lines/:id/use` — Sacar da linha de crédito
**Request:**
```json
{
  "amount_cents": 50000,
  "reference": "Saque para reforma"
}
```

**Response (200):**
```json
{
  "credit_line_id": "cl-001-...",
  "available_cents": 300000,
  "amount_drawn_cents": 50000,
  "created_at": "2026-06-05T14:30:00Z"
}
```

**Response (422 — saldo insuficiente):**
```json
{
  "status": "insufficient",
  "available_cents": 350000,
  "requested_cents": 500000
}
```

---

## 1. Listagem de Linhas de Crédito (`/credit-lines`)

```
┌─────────────────────────────────────────────────────────┐
│  Linhas de Crédito                       [+ Nova]       │
│                                                     │
│  ┌── Resumo ───────────────────────────────────────┐   │
│  │                                                   │   │
│  │  Limite Total:            R$ 5.000,00            │   │
│  │  Disponível Total:        R$ 3.500,00            │   │
│  │  Utilizado Total:        R$ 1.500,00            │   │
│  │                                                   │   │
│  │  ████████████████████░░░░░░░░░ 70% disponível    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Linha de Crédito Padrão  ✅ Ativa    Limite: 5k │ │
│  │ Disponível: R$ 3.500,00   Taxa: 12.5% a.a.   👁️ │ │
│  │ ████████████████░░░░░░ 70%                     │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Card de Linha de Crédito
| Elemento | Fonte |
|----------|-------|
| Nome | "Linha de Crédito" + `status` (badge) |
| Limite | `limit_cents` formatado |
| Disponível | `available_cents` formatado |
| Utilizado | `limit_cents - available_cents` |
| Taxa | `annual_rate` + "% a.a." |
| Barra progresso | `available_cents / limit_cents` |
| Ação 👁️ | Abre modal de saque ou navega para `/credit-lines/:id` |

---

## 2. Formulário de Contratação (`/credit-lines/new`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Linhas de Crédito   Nova Linha de Crédito            │
│                                                     │
│  ┌── Formulário ────────────────────────────────────┐  │
│  │                                                   │  │
│  │  Limite Desejado (R$) *                          │  │
│  │  [___________5.000,00_______________]            │  │
│  │                                                   │  │
│  │  Taxa de Juros Anual (%)                         │  │
│  │  [___________12,50________________]              │  │
│  │                                                   │  │
│  │  ⚠️ A taxa pode variar conforme análise de      │  │
│  │     crédito. Valores finais serão confirmados.   │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ [Cancelar]                  [Contratar]     │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Campos
| Campo | Tipo | Obrigatório |
|-------|------|-------------|
| `limit_cents` | money | Sim |
| `annual_rate` | decimal | Sim |

---

## 3. Modal de Saque (uso da linha)

Acessado pelo botão "Sacar" no card da linha de crédito.

```
┌───────────────────────────────────────────────┐
│  Sacar da Linha de Crédito                    │
│                                               │
│  Linha: Linha de Crédito Padrão              │
│  Disponível: R$ 3.500,00                     │
│  Taxa: 12,5% a.a.                            │
│                                               │
│  Valor do Saque (R$) *                       │
│  [___________500,00________________]         │
│                                               │
│  Referência (opcional)                       │
│  [Saque para reforma do espaço            ]  │
│                                               │
│  ┌─────────────────────────────────────────┐ │
│  │            [Cancelar]  [Sacar]          │ │
│  └─────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

### Validações
- Valor do saque não pode exceder `available_cents`
- Exibir erro "Saldo insuficiente" se ultrapassar

---

## 4. Estado de Erro (Saldo Insuficiente)

```json
// Response 422
{
  "status": "insufficient",
  "available_cents": 350000,
  "requested_cents": 500000
}
```

Exibir toast:
```
❌ Saldo insuficiente.
Disponível: R$ 3.500,00
Solicitado: R$ 5.000,00
```

---

## Dados do Frontend

```typescript
const useCreditLines = (orgId: string) => ({
  queryKey: ['creditLines', orgId],
  queryFn: () => fetch(`/api/v1/credit_lines?organization_id=${orgId}`)
});

const useCreditLine = (id: string) => ({
  queryKey: ['creditLines', id],
  queryFn: () => fetch(`/api/v1/credit_lines/${id}`)
});
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Lista crédito | 1 min | Ao contratar/sacar |
| Detalhe | 30s | Após saque |
