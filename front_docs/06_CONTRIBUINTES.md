# Tela de Contribuintes

**Rotas:**
- Listagem: `/contributors`
- Detalhe: `/contributors/:id`

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/contributors` — Listar contribuintes
**Header:** `X-API-Key`

**Response:**
```json
[
  {
    "id": "ctb-001-...",
    "organization_id": "org-...",
    "name": "João Silva",
    "email": "joao@email.com",
    "cpf": "123.456.789-00",
    "phone": "(11) 99999-8888",
    "status": "active",
    "created_at": "2026-01-20T14:00:00Z"
  }
]
```

### GET `/api/v1/contributors/:id` — Detalhe do contribuinte
**Response:**
```json
{
  "id": "ctb-001-...",
  "organization_id": "org-...",
  "name": "João Silva",
  "email": "joao@email.com",
  "cpf": "123.456.789-00",
  "phone": "(11) 99999-8888",
  "status": "active",
  "created_at": "2026-01-20T14:00:00Z"
}
```

### POST `/api/v1/contributors` — Criar contribuinte
**Request:**
```json
{
  "contributor": {
    "name": "João Silva",
    "email": "joao@email.com",
    "organization_id": "org-...",
    "cpf": "123.456.789-00",
    "phone": "(11) 99999-8888"
  }
}
```

**Response (201):**
```json
{
  "contributor": {
    "contributor_id": "ctb-001-...",
    "name": "João Silva",
    "email": "joao@email.com"
  }
}
```

### GET `/api/v1/contributors/:id/recurring_donations` — Doações recorrentes do contribuinte
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
    "status": "active",
    "next_charge_date": "2026-07-05",
    "campaign_id": "c001-...",
    "created_at": "2026-05-01T10:00:00Z"
  }
]
```

---

## 1. Listagem de Contribuintes (`/contributors`)

```
┌─────────────────────────────────────────────────────────┐
│  Contribuintes                            [+ Novo]      │
│                                                     │
│  Buscar: [_____________________________]              │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 👤 João Silva      joao@email.com      Ativo   │ │
│  │   1 doação recorrente · R$ 50/mês       👁️    │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 👤 Maria Santos    maria@email.com     Ativo   │ │
│  │   2 doações recorrentes · R$ 120/mês    👁️    │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 👤 Pedro Alves     pedro@email.com     Inativo │ │
│  │   0 doações recorrentes                👁️    │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Card de Contribuinte
| Elemento | Fonte |
|----------|-------|
| Nome | `name` |
| Email | `email` |
| Status | `status` (badge: active=verde, inactive=cinza) |
| Resumo doações | `GET /contributors/:id/recurring_donations` (count + total mensal) |
| Ação 👁️ | Link para `/contributors/:id` |

---

## 2. Detalhe do Contribuinte (`/contributors/:id`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Contribuintes              João Silva                │
│                                                     │
│  ┌── Dados do Contribuinte ────────────────────────┐   │
│  │                                                   │   │
│  │  Nome:   João Silva                              │   │
│  │  Email:  joao@email.com                          │   │
│  │  CPF:    123.456.789-00                           │   │
│  │  Phone:  (11) 99999-8888                          │   │
│  │  Status: ✅ Ativo                                 │   │
│  │  Membro desde: 20/01/2026                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Carteira ─────────────────────────────────────┐   │
│  │                                                   │   │
│  │  Saldo Disponível: R$ 150,00                     │   │
│  │  [Ver transações] →                              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Doações Recorrentes ──────────────────────────┐   │
│  │                                                   │   │
│  │  Festa Junina          R$ 50,00/mês  Ativo   👁️ │   │
│  │  Próxima cobrança: 05/07/2026                   │   │
│  │                                                   │   │
│  │  Campanha Agasalho     R$ 30,00/mês  Ativo   👁️ │   │
│  │  Próxima cobrança: 12/07/2026                   │   │
│  │                                                   │   │
│  │  [Nova Doação Recorrente]                        │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Formulário de Novo Contribuinte

Acesso pelo botão "[+ Novo]" na listagem.

```
┌─────────────────────────────────────────────────────────┐
│  ← Contribuintes              Novo Contribuinte         │
│                                                     │
│  ┌── Formulário ────────────────────────────────────┐  │
│  │                                                   │  │
│  │  Nome *                                          │  │
│  │  [__________________________________________]   │  │
│  │                                                   │  │
│  │  Email *                                         │  │
│  │  [__________________________________________]   │  │
│  │                                                   │  │
│  │  CPF                                              │  │
│  │  [___.___.___-__]                                │  │
│  │                                                   │  │
│  │  Telefone                                         │  │
│  │  [(__) _____-____]                               │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ [Cancelar]                     [Salvar]     │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Campos
| Campo | Tipo | Obrigatório | Validações |
|-------|------|-------------|------------|
| `name` | text | Sim | Mín. 3 caracteres |
| `email` | email | Sim | Formato email válido |
| `cpf` | text (mask) | Não | 11 dígitos, validar dígitos verificadores |
| `phone` | text (mask) | Não | Formato (11) 99999-8888 |

### Máscaras
```typescript
// CPF: 123.456.789-00
// Telefone: (11) 99999-8888
```

---

## Dados do Frontend

```typescript
// Cache
const useContributors = (orgId: string) => ({
  queryKey: ['contributors'],
  queryFn: () => fetch('/api/v1/contributors')
});

const useContributor = (id: string) => ({
  queryKey: ['contributors', id],
  queryFn: () => fetch(`/api/v1/contributors/${id}`)
});
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Lista contribuintes | 1 minuto | Ao criar novo |
| Detalhe contribuinte | 1 minuto | Manual |
| Doações recorrentes | 30 segundos | Manual |
