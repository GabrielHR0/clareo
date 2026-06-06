# Tela de Membros (Memberships)

**Rota:** `/memberships`
**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/memberships?organization_id=:org_id` — Listar membros
**Header:** `X-API-Key: <api_key>`

**Response:**
```json
[
  {
    "id": "mem-001-...",
    "organization_id": "org-...",
    "contributor_id": "ctb-001-...",
    "role": "admin",
    "created_at": "2026-01-20T14:00:00Z"
  }
]
```

### POST `/api/v1/memberships` — Vincular contribuinte
**Request:**
```json
{
  "membership": {
    "organization_id": "org-...",
    "contributor_id": "ctb-001-...",
    "role": "user"
  }
}
```

**Response (201):**
```json
{
  "membership_id": "mem-001-..."
}
```

### GET `/api/v1/memberships?contributor_id=:contributor_id` — Consultar por contribuinte

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│  Membros da Organização                [+ Adicionar]    │
│                                                     │
│  Buscar: [_____________________________]              │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 👤 João Silva        joao@email.com     Admin  │ │
│  │ Membro desde: 20/01/2026              🗑️      │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 👤 Maria Santos     maria@email.com    Usuário │ │
│  │ Membro desde: 15/03/2026              🗑️      │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 👤 Pedro Alves      pedro@email.com   Usuário │ │
│  │ Membro desde: 01/04/2026              🗑️      │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Tabela
| Coluna | Fonte |
|--------|-------|
| Nome | `contributor_id` → lookup no GET contributor |
| Email | `contributor_id` → lookup no GET contributor |
| Papel | `role` (admin, user) |
| Desde | `created_at` |
| Ação 🗑️ | Remover membro (DELETE — pendente no backend) |

---

## Modal de Adicionar Membro

```
┌───────────────────────────────────────┐
│  Adicionar Membro                     │
│                                       │
│  Contribuinte *                      │
│  [Selecionar contribuinte       ▼]   │
│                                       │
│  Papel                               │
│  [Usuário                    ▼]      │
│                                       │
│  [Cancelar]  [Adicionar]            │
└───────────────────────────────────────┘
```

### Campos
| Campo | Tipo | Opções |
|-------|------|--------|
| `contributor_id` | select | Lista de contribuintes da org |
| `role` | select | "admin", "user" |

---

## Dados do Frontend

```typescript
const useMemberships = (orgId: string) => ({
  queryKey: ['memberships', orgId],
  queryFn: () => fetch(`/api/v1/memberships?organization_id=${orgId}`)
});
```
