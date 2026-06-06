# Tela Pública de Prestação de Contas

**Rota:** `/public/accountability/:campaignId`
**Público:** Sim (não requer autenticação)
**Objetivo:** Página pública de transparência que mostra como os recursos de uma campanha foram utilizados. Qualquer pessoa pode acessar sem login.

---

## Endpoint Utilizado

### GET `/api/v1/public/campaigns/:campaign_id/accountability` — Relatório público
**Header:** Nenhum (público)

**Response (200):**
```json
{
  "organization": {
    "id": "org-...",
    "name": "Instituto Vida"
  },
  "campaign": {
    "campaign_id": "c001-...",
    "name": "Festa Junina Beneficente",
    "description": "Arrecadação para festa junina da comunidade",
    "goal_cents": 1000000,
    "status": "active",
    "starts_at": "2026-05-01T00:00:00Z",
    "ends_at": "2026-07-01T00:00:00Z"
  },
  "summary": {
    "total_raised": 800000,
    "total_spent": 200000,
    "balance": 600000,
    "expense_count": 8
  },
  "expenses": [
    {
      "entry_id": "e001-...",
      "description": "Buffet para festa junina",
      "amount_cents": 50000,
      "category": "Alimentação",
      "expense_date": "2026-06-01",
      "status": "paid",
      "created_at": "2026-05-20T10:00:00Z",
      "attachments": [
        {
          "attachment_id": "a001-...",
          "filename": "nota-fiscal.pdf",
          "original_filename": "NF_12345.pdf",
          "content_type": "application/pdf",
          "file_size": 245760,
          "created_at": "2026-05-20T10:05:00Z"
        }
      ]
    }
  ]
}
```

**Response (404):**
```json
{
  "error": "not_found"
}
```

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│                    LOGO CLAREO                          │
│                                                 │
│  ┌─────────────────────────────────────────────────┐  │
│  │  📊 Prestação de Contas                         │  │
│  │                                                 │  │
│  │  🏢 Instituto Vida                             │  │
│  │  🎯 Campanha: Festa Junina Beneficente          │  │
│  │                                                 │  │
│  │  ┌──────┬─────────┬────────┬────────────────┐  │  │
│  │  │ 💰   │ 📊     │ 💳    │ 📄             │  │  │
│  │  │ R$ 8.000  │ R$ 2.000  │ R$ 6.000 │ 8 despesas  │  │
│  │  │ Arrecadado│ Gasto    │ Saldo   │             │  │
│  │  └──────┴─────────┴────────┴────────────────┘  │  │
│  │                                                 │  │
│  │  ┌── Gráfico de Alocação ────────────────────┐ │  │
│  │  │   🥧 Distribuição dos Gastos              │ │  │
│  │  │                                           │ │  │
│  │  │     ████████  Alimentação     R$ 800     │ │  │
│  │  │     ██████    Estrutura      R$ 600     │ │  │
│  │  │     ████      Divulgação     R$ 400     │ │  │
│  │  │     ██        Transporte     R$ 200     │ │  │
│  │  └───────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────┘  │
│                                                 │
│  ┌── Detalhamento das Despesas ────────────────┐   │
│  │                                                 │  │
│  │  📄 Buffet                    R$ 500,00        │  │
│  │     Alimentação · 01/06/2026 · Pago           │  │
│  │     📎 NF_12345.pdf 245 KB [📥]               │  │
│  │  ─────────────────────────────────────────    │  │
│  │  📄 Toldo                     R$ 400,00        │  │
│  │     Estrutura · 25/05/2026 · Pago             │  │
│  │     📎 recibo_toldo.jpg 1.2 MB [📥]           │  │
│  │  ─────────────────────────────────────────    │  │
│  │  📄 Panfletos                 R$ 200,00        │  │
│  │     Divulgação · 15/05/2026 · Pago            │  │
│  │     (sem anexos)                               │  │
│  │  ─────────────────────────────────────────    │  │
│  │  📄 Transporte de materiais   R$ 200,00        │  │
│  │     Transporte · 10/05/2026 · Pago            │  │
│  │     📎 NF_transporte.pdf 150 KB  [📥]         │  │
│  └─────────────────────────────────────────────────┘ │
│                                                 │
│  ┌── Timeline ─────────────────────────────────┐   │
│  │  Linha do tempo de arrecadação vs gastos    │   │
│  │                                             │   │
│  │  📅 01/05 — Início da campanha              │   │
│  │  💰 +R$ 500 — Primeira doação               │   │
│  │  💰 +R$ 300 — Doação PIX                   │   │
│  │  💳 -R$ 200 — Pagamento buffet              │   │
│  │  💰 +R$ 1000 — Doação cartão               │   │
│  │  💳 -R$ 400 — Pagamento toldo              │   │
│  │  ...                                        │   │
│  └─────────────────────────────────────────────────┘ │
│                                                 │
│  ┌── Footer ───────────────────────────────────┐   │
│  │  💡 Quer contribuir?                        │   │
│  │                                             │   │
│  │  [Fazer uma Doação]                         │   │
│  │                                             │   │
│  │  📅 Última atualização: 05/06/2026          │   │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Seções

### 1. Header
- Logo Clareo
- Título "Prestação de Contas"
- Nome da organização
- Nome da campanha
- Link "Fazer uma Doação" → `/public/donate/:campaignId`

### 2. Cards de Resumo (4 cards lado a lado)

| Card | Fonte | Formatação |
|------|-------|-----------|
| Total Arrecadado | `summary.total_raised` | R$ 8.000,00 |
| Total Gasto | `summary.total_spent` | R$ 2.000,00 |
| Saldo Restante | `summary.balance` | R$ 6.000,00 (verde) |
| Qtd. Despesas | `summary.expense_count` | 8 despesas |

### 3. Gráfico de Pizza — Distribuição por Categoria
Agrupar `expenses` por `category` e somar `amount_cents`:

| Categoria | Total | % |
|-----------|-------|---|
| Alimentação | R$ 800 | 40% |
| Estrutura | R$ 600 | 30% |
| Divulgação | R$ 400 | 20% |
| Transporte | R$ 200 | 10% |

**Visualização:** Gráfico de pizza (Chart.js, Recharts, ou SVG puro) + legenda com valores.

### 4. Lista de Despesas (detalhada)

Cada item:
| Elemento | Fonte |
|----------|-------|
| Ícone | 📄 (fixo) |
| Descrição | `description` |
| Valor | `amount_cents` formatado |
| Categoria | `category` |
| Data | `expense_date` formatado (DD/MM/AAAA) |
| Status | `status` (paid=Pago) |
| Anexos | Lista de `attachments` com [📥 Download] |
| Separador | Linha horizontal entre itens |

### 5. Timeline (opcional)
Se disponível, exibe uma linha do tempo com transações de crédito (doações recebidas) e despesas pagas, em ordem cronológica.

**Fonte:** Não vem no accountability report atual. Pode ser adicionada futuramente via endpoint separado ou incluída no report.

### 6. Footer
- Botão "Fazer uma Doação" → link para `/public/donate/:campaignId`
- Data da última atualização

---

## Estados da Tela

### Carregando
```
Skeleton: 4 cards pulando + lista de itens cinza
```

### Campanha não encontrada
```
┌─────────────────────────────────────┐
│  ❌ Campanha não encontrada        │
│                                     │
│  Verifique se o link está correto. │
│                                     │
│  [Voltar para página inicial]      │
└─────────────────────────────────────┘
```

### Campanha sem despesas
```
┌─────────────────────────────────────┐
│  📊 Prestação de Contas            │
│                                     │
│  Ainda não há despesas registradas │
│  para esta campanha.               │
│                                     │
│  Total arrecadado: R$ 8.000,00     │
│  Aguardando prestação de contas.   │
└─────────────────────────────────────┘
```

---

## Download de Anexos

Para cada anexo, o link de download é público (endpoint sem auth):

```
GET /api/v1/public/campaigns/:campaign_id/expenses/:expense_id/attachments/:attachment_id/download
```

> **Pendência:** O endpoint atual (`GET .../expenses/:id/attachments/:id/download`) requer autenticação. Precisa de uma rota pública ou o accountability já deve resolver isso.

---

## Meta Tags para SEO/Sharing
```html
<meta property="og:title" content="Prestação de Contas - Festa Junina Beneficente" />
<meta property="og:description" content="Veja como R$ 8.000,00 arrecadados foram utilizados." />
<meta property="og:image" content="..." />
```

---

## Dados no Frontend

```typescript
const useAccountability = (campaignId: string) => ({
  queryKey: ['accountability', campaignId],
  queryFn: () => fetch(`/api/v1/public/campaigns/${campaignId}/accountability`),
  cacheTime: 5 * 60 * 1000, // 5 min — dados públicos, pode cachear mais
});

// Agrupar despesas por categoria para o gráfico
interface CategorySummary {
  category: string;
  totalCents: number;
  percentage: number;
}

function groupByCategory(expenses: Expense[]): CategorySummary[] {
  const total = expenses.reduce((s, e) => s + e.amount_cents, 0);
  const groups: Record<string, number> = {};
  for (const exp of expenses) {
    groups[exp.category] = (groups[exp.category] || 0) + exp.amount_cents;
  }
  return Object.entries(groups).map(([cat, sum]) => ({
    category: cat,
    totalCents: sum,
    percentage: Math.round((sum / total) * 100)
  }));
}
```

| Dado | Cache |
|------|-------|
| Relatório | 5 minutos (público, muda pouco) |
| Anexos | Sem cache (download direto) |
