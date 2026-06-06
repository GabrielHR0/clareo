# Tela de Métodos de Pagamento

**Rota:** `/payment-methods`
**Público:** Não (requer `X-API-Key`)

---

## Endpoint Utilizado

### POST `/api/v1/owners/organization/:org_id/payment_methods` — Adicionar método
**Header:** `X-API-Key: <api_key>`

**Request:**
```json
{
  "method_type": "credit_card",
  "details": {
    "card_brand": "visa",
    "last_four": "1234",
    "holder_name": "Instituto Vida",
    "token": "tok_gateway_001"
  },
  "is_default": true
}
```

**Response (201):**
```json
{
  "payment_method_id": "pm-001-...",
  "owner_type": "organization",
  "owner_id": "org-...",
  "payment_type": "credit_card",
  "reference": "visa_1234",
  "is_default": true,
  "created_at": "2026-06-01T10:00:00Z"
}
```

---

## Layout da Tela

```
┌─────────────────────────────────────────────────────────┐
│  Métodos de Pagamento                  [+ Novo]         │
│                                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 💳 Visa final 1234                  Padrão ✅  │ │
│  │ Titular: Instituto Vida                         │ │
│  │ Adicionado em: 01/06/2026                 🗑️  │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Card de Método
| Elemento | Fonte |
|----------|-------|
| Ícone | `details.card_brand` |
| Bandeira + final | `details.card_brand + " final " + details.last_four` |
| Titular | `details.holder_name` |
| Padrão | Badge se `is_default = true` |
| Ação 🗑️ | Remover (DELETE — pendente no backend) |

### Formulário de Novo Método
- Tipo (select): credit_card, bank_transfer, pix
- Bandeira (select): visa, mastercard, elo, amex
- Nome do titular
- Token (gerado por gateway externo)
- Definir como padrão (checkbox)

---

## Dados do Frontend

```typescript
// Importante: O frontend nunca deve enviar número de cartão.
// O token é gerado por um gateway externo (Stripe, Pagar.me).
```
