# Tela de Configurações da Organização

**Rota:** `/settings`
**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/organizations/:id` — Dados da organização
**Header:** `X-API-Key: <api_key>`

**Response:**
```json
{
  "id": "org-...",
  "name": "Instituto Vida",
  "cnpj": "12.345.678/0001-90",
  "contact_email": "contato@vidar.org",
  "webhook_url": "https://vidar.org/webhooks/clareo",
  "status": "active",
  "external_id": null,
  "created_at": "2026-01-15T10:00:00Z"
}
```

> **Nota:** O campo `api_key_hash` NÃO é retornado por segurança.

### POST `/api/v1/organizations` — Criar organização (já coberto no login)

### PATCH `/api/v1/organizations/:id` — Atualizar organização (pendente no backend)

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│  ← Dashboard              Configurações                 │
│                                                     │
│  ┌── Dados da Organização ─────────────────────────┐   │
│  │                                                   │   │
│  │  Nome *                                         │   │
│  │  [Instituto Vida_____________________________]  │   │
│  │                                                   │   │
│  │  CNPJ                                            │   │
│  │  [12.345.678/0001-90________________________]   │   │
│  │                                                   │   │
│  │  Email de Contato                                │   │
│  │  [contato@vidar.org_________________________]   │   │
│  │                                                   │   │
│  │  Webhook URL (notificações de doações)           │   │
│  │  [https://vidar.org/webhooks/clareo________]    │   │
│  │                                                   │   │
│  │  Status                                           │   │
│  │  [Ativa                     ▼]                   │   │
│  │                                                   │   │
│  │  ┌─────────────────────────────────────────────┐ │   │
│  │  │                  [Salvar]                   │ │   │
│  │  └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── API Key ─────────────────────────────────────┐   │
│  │                                                   │   │
│  │  Sua chave de acesso permite que sistemas        │   │
│  │  externos se conectem à API Clareo.              │   │
│  │                                                   │   │
│  │  ⚠️  A chave atual não pode ser recuperada.      │   │
│  │     Se perder, gere uma nova (a anterior será    │   │
│  │     invalidada).                                  │   │
│  │                                                   │   │
│  │  [🔄 Regenerar API Key]                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Zona de Perigo ──────────────────────────────┐   │
│  │                                                   │   │
│  │  ⚠️  Excluir Conta                              │   │
│  │     Remove permanentemente a organização e      │   │
│  │     todos os dados associados.                  │   │
│  │                                                   │   │
│  │  [Excluir Organização]                          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Campos do Formulário

| Campo | Tipo | Obrigatório | Validação |
|-------|------|-------------|-----------|
| `name` | text | Sim | Mín. 3 caracteres |
| `cnpj` | text (mask) | Não | 14 dígitos com validação |
| `contact_email` | email | Não | Formato email |
| `webhook_url` | url | Não | URL válida (https) |
| `status` | select | Não | active, inactive |

### Máscaras
```typescript
// CNPJ: 12.345.678/0001-90
// Aplicar máscara automática enquanto digita
```

---

## Seção: API Key

### Fluxo de Regeneração

1. Usuário clica em "Regenerar API Key"
2. Modal de confirmação:
```
┌─────────────────────────────────────┐
│  ⚠️  Regenerar API Key              │
│                                     │
│  A chave atual será invalidada      │
│  imediatamente. Todos os sistemas   │
│  usando esta chave pararão de       │
│  funcionar até serem atualizados.   │
│                                     │
│  [Cancelar]  [Confirmar]           │
└─────────────────────────────────────┘
```
3. `POST /api/v1/organizations/:id/regenerate_key` (pendente no backend)
4. Exibir nova chave (mesmo fluxo de criação — mostrar uma vez)

---

## Seção: Zona de Perigo

### Exclusão de Conta
1. Usuário clica em "Excluir Organização"
2. Modal de confirmação com input de texto:
```
┌───────────────────────────────────────────┐
│  ⚠️  Excluir Organização                  │
│                                           │
│  Esta ação é irreversível. Todos os      │
│  dados serão permanentemente removidos.  │
│                                           │
│  Digite "EXCLUIR" para confirmar:        │
│  [________________]                      │
│                                           │
│  [Cancelar]  [Excluir]                   │
└───────────────────────────────────────────┘
```
3. `DELETE /api/v1/organizations/:id` (pendente no backend)

---

## Pendências no Backend

- [ ] `PATCH /api/v1/organizations/:id` — Atualizar dados
- [ ] `POST /api/v1/organizations/:id/regenerate_key` — Regenerar API key
- [ ] `DELETE /api/v1/organizations/:id` — Excluir organização
- [ ] Retornar `webhook_url` e `contact_email` no GET organization

---

## Dados do Frontend

```typescript
const useOrganization = (id: string) => ({
  queryKey: ['organization', id],
  queryFn: () => fetch(`/api/v1/organizations/${id}`)
});
```

| Dado | Cache | Refetch |
|------|-------|---------|
| Dados organização | 5 min | Ao salvar |
