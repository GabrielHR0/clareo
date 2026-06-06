# Tela de Despesas

**Rotas:**
- Listagem: `/campaigns/:campaignId/expenses`
- Criar: `/campaigns/:campaignId/expenses/new`
- Detalhe: `/campaigns/:campaignId/expenses/:id`
- Editar: `/campaigns/:campaignId/expenses/:id/edit`

**Público:** Não (requer `X-API-Key`)

---

## Endpoints Utilizados

### GET `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses` — Listar
**Query params:** `?limit=100`

**Response:**
```json
[
  {
    "entry_id": "e001-...",
    "organization_id": "org-...",
    "campaign_id": "c001-...",
    "description": "Buffet para festa junina",
    "amount_cents": 20000,
    "category": "Alimentação",
    "expense_date": "2026-06-05",
    "status": "paid",
    "created_at": "2026-06-01T10:00:00Z"
  }
]
```

### POST `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses` — Criar
**Request:**
```json
{
  "expense": {
    "description": "Buffet para festa junina",
    "amount_cents": 20000,
    "category": "Alimentação",
    "expense_date": "2026-06-05",
    "status": "paid"
  }
}
```

**Response (201):**
```json
{
  "entry_id": "e001-...",
  "organization_id": "org-...",
  "campaign_id": "c001-..."
}
```

### GET `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:id` — Detalhe
**Response:**
```json
{
  "entry_id": "e001-...",
  "organization_id": "org-...",
  "campaign_id": "c001-...",
  "description": "Buffet para festa junina",
  "amount_cents": 20000,
  "category": "Alimentação",
  "expense_date": "2026-06-05",
  "status": "paid",
  "created_at": "2026-06-01T10:00:00Z",
  "attachments": [
    {
      "attachment_id": "a001-...",
      "filename": "nota-fiscal.pdf",
      "original_filename": "NF_12345.pdf",
      "content_type": "application/pdf",
      "file_size": 245760,
      "created_at": "2026-06-01T10:05:00Z"
    }
  ]
}
```

### PATCH `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:id` — Atualizar
**Request:** (mesmos campos do create, apenas os que forem alterados)

**Response:** ExpenseEntry atualizado

### DELETE `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:id` — Excluir
**Response:** `204 No Content`

### POST `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:expense_id/attachments` — Anexar arquivo
**Request:** `multipart/form-data` com campo `file`

**Response (201):**
```json
{
  "attachment_id": "a001-...",
  "filename": "nota-fiscal.pdf",
  "original_filename": "NF_12345.pdf"
}
```

### GET `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:expense_id/attachments/:attachment_id/download` — Download
**Response:** Arquivo binário com `Content-Type` apropriado

### DELETE `/api/v1/organizations/:org_id/campaigns/:campaign_id/expenses/:expense_id/attachments/:id` — Remover anexo
**Response:** `204 No Content`

---

## 1. Listagem de Despesas (`/campaigns/:id/expenses`)

Exibida dentro da aba "Despesas" no detalhe da campanha, ou como página dedicada.

```
┌─────────────────────────────────────────────────────────┐
│  ← Festa Junina           Despesas da Campanha          │
│                                                     │
│  ┌── Resumo ───────────────────────────────────────┐   │
│  │  Total de Despesas: R$ 2.000,00                 │   │
│  │  Nº de despesas: 8                               │   │
│  │  Média: R$ 250,00                                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Filtros ─────────────────────────────────────┐   │
│  │  Categoria: [Todas       ▼]                    │   │
│  │  Status:    [Todos       ▼]                    │   │
│  └────────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ [+ Nova Despesa]                               │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 📄 Buffet                    Categoria: Aliment.│ │
│  │    R$ 200,00  05/06/2026  Pago      📎2 👁️🗑️  │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 📄 Toldo                     Categoria: Estrut. │ │
│  │    R$ 150,00  01/06/2026  Pago      📎1 👁️🗑️  │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 📄 Palco                     Categoria: Estrut. │ │
│  │    R$ 500,00  25/05/2026  Pendente   📎0 👁️🗑️ │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Ações por Item
| Ação | Ícone | Comportamento |
|------|-------|---------------|
| Ver detalhe | 👁️ | Navega para `/campaigns/:id/expenses/:entry_id` |
| Excluir | 🗑️ | Modal de confirmação → `DELETE` → remove da lista |
| Download anexo | 📎 | Link direto para download (abre em nova aba) |

---

## 2. Formulário de Criar/Editar Despesa

```
┌─────────────────────────────────────────────────────────┐
│  ← Voltar                Nova Despesa                    │
│                                                     │
│  ┌── Formulário ────────────────────────────────────┐  │
│  │                                                   │  │
│  │  Descrição *                                     │  │
│  │  [__________________________________________]   │  │
│  │                                                   │  │
│  │  Valor (R$) *                                    │  │
│  │  [___________200,00______________]               │  │
│  │                                                   │  │
│  │  Categoria                                        │  │
│  │  [Alimentação               ▼]                   │  │
│  │                                                   │  │
│  │  Data da Despesa                                  │  │
│  │  [__05/06/2026__] ⌚                              │  │
│  │                                                   │  │
│  │  Status                                           │  │
│  │  [Pago                    ▼]                     │  │
│  │                                                   │  │
│  │  Anexos (opcional)                               │  │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │ 📎 Arraste arquivos aqui ou clique para     │ │ │
│  │  │    selecionar                                │ │ │
│  │  │                                             │ │ │
│  │  │ Arquivos selecionados:                      │ │ │
│  │  │ [NF_12345.pdf] [nota_fiscal.jpg]           │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │ [Cancelar]                     [Salvar]     │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Campos do Formulário

| Campo | Tipo | Obrigatório | Validações |
|-------|------|-------------|------------|
| `description` | text | Sim | Mín. 3 caracteres |
| `amount_cents` | money | Sim | Mín. R$ 0,01 |
| `category` | select | Não | Lista pré-definida (ver abaixo) |
| `expense_date` | date | Não | Padrão: data atual |
| `status` | select | Não | "paid", "pending", "cancelled" |
| `file` | file (multipart) | Não | PDF, JPG, PNG, max 10MB |

### Categorias Pré-definidas
```
Alimentação
Estrutura
Divulgação
Transporte
Pessoal
Material
Serviço
Impostos
Outros
```

### Upload de Arquivos
- **Múltiplos arquivos:** O formulário permite selecionar vários arquivos
- **Envio:** Cada arquivo é enviado individualmente via `POST .../attachments` após salvar a despesa
- **Preview:** Mostrar nome e tamanho do arquivo antes do upload
- **Remover:** Botão "X" para remover arquivo antes de enviar
- **Progresso:** Barra de progresso do upload (opcional)

### Fluxo de Salvamento
```typescript
// 1. Cria a despesa
const expense = await fetch(`POST /api/v1/organizations/${orgId}/campaigns/${campId}/expenses`, {
  body: JSON.stringify({ expense: { description, amount_cents, category, expense_date, status } })
});

// 2. Para cada arquivo, faz upload
for (const file of files) {
  const formData = new FormData();
  formData.append('file', file);
  await fetch(`POST /api/v1/organizations/${orgId}/campaigns/${campId}/expenses/${expense.entry_id}/attachments`, {
    method: 'POST',
    body: formData
  });
}
```

---

## 3. Detalhe da Despesa (`/campaigns/:id/expenses/:expenseId`)

```
┌─────────────────────────────────────────────────────────┐
│  ← Despesas                  Detalhe da Despesa          │
│                                                     │
│  ┌── Informações ──────────────────────────────────┐   │
│  │                                                   │   │
│  │  Descrição:  Buffet para festa junina             │   │
│  │  Valor:      R$ 200,00                            │   │
│  │  Categoria:  Alimentação                          │   │
│  │  Data:       05/06/2026                            │   │
│  │  Status:     ✅ Pago                              │   │
│  │  Criado em:  01/06/2026 às 10:00                  │   │
│  │                                                   │   │
│  │  [Editar]  [Excluir]                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                     │
│  ┌── Anexos ───────────────────────────────────────┐   │
│  │                                                   │   │
│  │  📎 NF_12345.pdf                   245 KB 📥    │   │
│  │  📎 nota_fiscal.jpg               1.2 MB 📥     │   │
│  │                                                   │   │
│  │  [Adicionar Anexo]                               │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Componente de Anexo
| Elemento | Descrição |
|----------|-----------|
| Ícone | 📎 (genérico) ou ícone do tipo de arquivo (PDF, imagem) |
| Nome | `original_filename` |
| Tamanho | Formatado: `245 KB`, `1.2 MB` |
| Botão 📥 | Download → abre `GET .../attachments/:id/download` em nova aba |
| Botão 🗑️ | Excluir → modal de confirmação → `DELETE` |

---

## Estados da Tela

### Lista vazia
```
Nenhuma despesa registrada para esta campanha.
[+ Registrar primeira despesa]
```

### Erro ao carregar
```
Toast: "Erro ao carregar despesas"
Botão: "Tentar novamente"
```

### Upload falhou
```
Toast ao lado do arquivo: "Falha no upload. Tentar novamente."
Botão: "🔄" para retentar apenas aquele arquivo
```
