# Tela Pública de Checkout / Doação

**Rota:** `/public/donate/:campaignId`
**Público:** Sim (não requer autenticação)
**Objetivo:** Página pública onde qualquer pessoa pode fazer uma doação para uma campanha específica.

---

## Endpoint Utilizado

### POST `/api/v1/public/checkout` — Processar doação
**Header:** Nenhum (público)

**Request:**
```json
{
  "checkout": {
    "campaign_id": "c001-...",
    "amount_cents": 5000,
    "idempotency_key": "ext_abc_123",
    "currency": "BRL",
    "contributor": {
      "name": "João Doador",
      "email": "joao@email.com",
      "cpf": "123.456.789-00",
      "phone": "(11) 99999-8888"
    },
    "payment": {
      "method": "card",
      "card_token": "tok_valid_001",
      "installments": 1
    },
    "metadata": {
      "source": "landing_page"
    }
  }
}
```

**Response (201 — sucesso):**
```json
{
  "status": "ok",
  "transaction_id": "t001-...",
  "provider_reference": "ref_gateway_001"
}
```

**Response (200 — idempotente, já processado):**
```json
{
  "status": "already_processed",
  "transaction_id": "t001-..."
}
```

**Response (422 — erro):**
```json
{
  "status": "insufficient_funds",
  "transaction_id": null
}
```

> **Idempotência:** O campo `idempotency_key` deve ser único por doação. Se a mesma chave for reenviada, retorna o mesmo `transaction_id` sem processar novamente. O frontend deve gerar uma chave única (ex: UUID + timestamp).

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│                    LOGO CLAREO                          │
│                                                 │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Doe para: Festa Junina Beneficente              │  │
│  │                                                 │  │
│  │  ████████████████████████░░░░░ R$ 8.000        │  │
│  │  80% arrecadado de R$ 10.000                    │  │
│  └─────────────────────────────────────────────────┘  │
│                                                 │
│  ┌── Formulário de Doação ──────────────────────┐  │
│  │                                                 │  │
│  │  💳 Quanto você quer doar?                     │  │
│  │                                                 │  │
│  │  [R$ 30]  [R$ 50]  [R$ 100]  [R$ ░░░]        │  │
│  │                                                 │  │
│  │  ── Seus Dados ──                              │  │
│  │                                                 │  │
│  │  Nome Completo *                               │  │
│  │  [__________________________________________] │  │
│  │                                                 │  │
│  │  Email *                                       │  │
│  │  [__________________________________________] │  │
│  │                                                 │  │
│  │  CPF (para recibo)                             │  │
│  │  [___.___.___-__]                              │  │
│  │                                                 │  │
│  │  Telefone                                      │  │
│  │  [(__) _____-____]                             │  │
│  │                                                 │  │
│  │  ── Pagamento ──                               │  │
│  │                                                 │  │
│  │  [💳 Cartão]  [📱 PIX]  [📄 Boleto]            │  │
│  │                                                 │  │
│  │  Número do Cartão                              │  │
│  │  [____ ____ ____ ____]                         │  │
│  │                                                 │  │
│  │  Validade            CVV                       │  │
│  │  [MM/AA]             [___]                    │  │
│  │                                                 │  │
│  │  Nome no Cartão                                │  │
│  │  [__________________________________________] │  │
│  │                                                 │  │
│  │  Parcelas                                       │  │
│  │  [1x R$ 50,00              ▼]                 │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │    Doar R$ 50,00                        │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  │                                                 │  │
│  │  🔒 Pagamento processado com segurança         │  │
│  └─────────────────────────────────────────────────┘  │
│                                                 │
│  ┌── Prestação de Contas ──────────────────────┐   │
│  │  Ver como os recursos serão utilizados:     │   │
│  │  [Ver Prestação de Contas] →               │   │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Seções

### 1. Header da Campanha
- Nome da campanha
- Barra de progresso com valor arrecadado e meta

### 2. Seleção de Valor (sugestões + custom)
| Botão | Valor |
|-------|-------|
| R$ 30 | 3000 cents |
| R$ 50 | 5000 cents |
| R$ 100 | 10000 cents |
| Custom | Input livre |

### 3. Formulário de Dados do Doador
| Campo | Tipo | Obrigatório | Validação |
|-------|------|-------------|-----------|
| `name` | text | Sim | Mín. 3 caracteres |
| `email` | email | Sim | Formato email |
| `cpf` | text (mask) | Não | 11 dígitos |
| `phone` | text (mask) | Não | (11) 99999-8888 |

### 4. Método de Pagamento (abas)
| Método | Ícone | Comportamento |
|--------|-------|---------------|
| Cartão | 💳 | Mostra campos de cartão |
| PIX | 📱 | Gera QR Code + chave PIX |
| Boleto | 📄 | Gera link para boleto |

### 5. Formulário de Cartão (quando método=card)
| Campo | Tipo | Validação |
|-------|------|-----------|
| Número | text (mask) | 16 dígitos |
| Validade | text (mask) | MM/AA |
| CVV | text (mask) | 3-4 dígitos |
| Nome no Cartão | text | Mín. 3 caracteres |
| Parcelas | select | 1x a 12x |

> **Nota:** O frontend **não deve** enviar dados de cartão diretamente para a API Clareo. Deve usar um tokenizador (Stripe Elements, Pagar.me, etc.) e enviar apenas o `card_token`. O backend Clareo repassa o token para o gateway.

### 6. Botão de Doação
- **Label dinâmica:** "Doar R$ 50,00"
- **Estado de loading:** Botão desabilitado + spinner
- **Proteção:** Desabilitar double-click

---

## Fluxo PIX

Se o método for PIX, o flow é diferente:

1. Frontend envia `POST /public/checkout` com `payment.method: "pix"`
2. Backend/create intent → retorna QR Code (base64 ou URL)
3. Frontend exibe QR Code na tela
4. Polling a cada 5s até confirmação (ou redirecionar para página de "aguardando")

```
┌─────────────────────────────────────┐
│  Doe com PIX                        │
│                                     │
│  Valor: R$ 50,00                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      ██████████████        │   │
│  │    ██            ██        │   │
│  │   █   ██████████  █       │   │
│  │   █   ██    ████  █       │   │
│  │    ██            ██        │   │
│  │      ██████████████        │   │
│  └─────────────────────────────┘   │
│                                     │
│  Escaneie o QR Code com seu        │
│  banco ou copie a chave PIX:       │
│  12345678-9012-3456-7890-123456789 │
│                                     │
│  [Copiar chave PIX]                │
│                                     │
│  ⏳ Aguardando confirmação...      │
└─────────────────────────────────────┘
```

---

## Estados da Tela

### Sucesso
```
┌─────────────────────────────────────┐
│  ✅ Doação confirmada!             │
│                                     │
│  R$ 50,00 para Festa Junina        │
│                                     │
│  Recibo enviado para               │
│  joao@email.com                    │
│                                     │
│  [Compartilhar]  [Nova Doação]     │
└─────────────────────────────────────┘
```

### Erro — Cartão recusado
```
❌ Pagamento recusado.
Tente novamente com outro cartão.
```

### Erro — Rede
```
❌ Erro de conexão.
Verifique sua internet e tente novamente.
```

### Idempotência (duplicata)
```
✅ Doação já registrada!
Você já fez esta doação anteriormente.
```

---

## Geração de Idempotency Key

```typescript
// Gerar chave única para cada tentativa de doação
function generateIdempotencyKey(): string {
  return `donate_${crypto.randomUUID()}_${Date.now()}`;
}
```

---

## Dados do Frontend

```typescript
// Não usa React Query (dados não são cacheados)
// A campanha é carregada via GET /api/v1/organizations/:org_id/campaigns/:campaign_id
// Mas o frontend público precisa primeiro resolver org_id a partir do link.

// Fluxo:
// 1. URL: /public/donate/:campaignId
// 2. Precisa saber a organização. A API atual não tem endpoint público
//    para buscar campanha sem auth. Pendente: criar GET /api/v1/public/campaigns/:id
// 3. Alternativa: codificar org_id na URL: /public/donate/:orgId/:campaignId
```

### Pendências no Backend
- [ ] Criar `GET /api/v1/public/campaigns/:campaign_id` (público, sem auth)
- [ ] Criar `GET /api/v1/public/organizations/:id` (resumo público)
