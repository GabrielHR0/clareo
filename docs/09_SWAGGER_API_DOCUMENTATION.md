# API Documentation - Swagger/OpenAPI

## Overview

Clareo API is fully documented using OpenAPI 3.0 (Swagger) specification. The interactive documentation allows you to explore all endpoints, see request/response examples, and test the API directly from your browser.

## Accessing the Documentation

### Interactive Swagger UI (Recommended)

Once Rails server is running, visit:

```
http://localhost:3000/api-docs
```

### OpenAPI/Swagger JSON

```
http://localhost:3000/api-docs/swagger.json
```

### API Versioning

All business endpoints are versioned under `/api/v1`.
You can also access them without the prefix (e.g., both `/api/v1/organizations` and `/organizations` work).

---

## API Endpoints Summary (44+ endpoints)

### Health (4 endpoints — NO AUTH)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/up` | Rails health check |
| `GET` | `/health/cassandra` | Cassandra health |
| `GET` | `/health/redis` | Redis health |
| `GET` | `/health/all` | Combined health |

### Auth (3 endpoints — NO AUTH for register/login)
| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/api/v1/auth/register` | Register new user |
| `POST` | `/api/v1/auth/login` | Login |
| `GET` | `/api/v1/auth/me` | Get current user (requires Bearer token) |

### Organizations (3 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/organizations` | List all |
| `POST` | `/api/v1/organizations` | Create (generates API Key) |
| `GET` | `/api/v1/organizations/{id}` | Get details |

### Contributors (3 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/contributors` | List all |
| `POST` | `/api/v1/contributors` | Create |
| `GET` | `/api/v1/contributors/{id}` | Get details |

### Memberships (2 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/memberships` | List |
| `POST` | `/api/v1/memberships` | Create |

### Wallets (1 endpoint)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/owners/{owner_type}/{owner_id}/wallet` | Get wallet |

### Transactions (4 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/api/v1/owners/{owner_type}/{owner_id}/transactions` | Create (credit/debit/transfer) |
| `GET` | `/api/v1/owners/{owner_type}/{owner_id}/transactions` | List |
| `GET` | `/api/v1/owners/{owner_type}/{owner_id}/transactions/{id}` | Get details |
| `GET` | `/api/v1/campaigns/{campaign_id}/transactions` | By campaign |

### Payment Methods (1 endpoint)
| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/api/v1/owners/{owner_type}/{owner_id}/payment_methods` | Create |

### Credit Lines (4 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/credit_lines` | List |
| `POST` | `/api/v1/credit_lines` | Create |
| `GET` | `/api/v1/credit_lines/{id}` | Get details |
| `POST` | `/api/v1/credit_lines/{id}/use` | Draw funds |

### Campaigns (3 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/organizations/{org_id}/campaigns` | List |
| `POST` | `/api/v1/organizations/{org_id}/campaigns` | Create |
| `GET` | `/api/v1/organizations/{org_id}/campaigns/{id}` | Get details |

### Expenses (5 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses` | List |
| `POST` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses` | Create |
| `GET` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{id}` | Get details |
| `PATCH` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{id}` | Update |
| `DELETE` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{id}` | Delete |

### Expense Attachments (3 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{exp_id}/attachments` | Upload |
| `GET` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{exp_id}/attachments/{id}/download` | Download |
| `DELETE` | `/api/v1/organizations/{org_id}/campaigns/{camp_id}/expenses/{exp_id}/attachments/{id}` | Delete |

### Recurring Donations (4 endpoints)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/contributors/{id}/recurring_donations` | List |
| `POST` | `/api/v1/contributors/{id}/recurring_donations` | Create |
| `PATCH` | `/api/v1/contributors/{id}/recurring_donations/{rec_id}` | Cancel |
| `DELETE` | `/api/v1/contributors/{id}/recurring_donations/{rec_id}` | Cancel |

### Public (2 endpoints — NO AUTH)
| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/api/v1/public/checkout` | Process donation |
| `GET` | `/api/v1/public/campaigns/{campaign_id}/accountability` | Accountability report |

### Dashboard (1 endpoint)
| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/v1/organizations/{id}/dashboard` | Dashboard with metrics |

---

## Authentication

Two security schemes are defined:

### JWT (Bearer Token) — for frontend users

```bash
# Register
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@email.com","password":"12345678","name":"User"}'

# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@email.com","password":"12345678"}'

# Use token
curl -X GET http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer <token>"
```

### API Key — for programmatic access

```bash
curl -X GET http://localhost:3000/api/v1/organizations \
  -H "X-API-Key: <your_api_key>"
```

---

## Transaction Flow Examples

### Credit
```bash
curl -X POST http://localhost:3000/owners/organization/<org_id>/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "amount_cents": 100000,
      "currency": "BRL",
      "transaction_type": "credit",
      "idempotency_key": "unique-key-123"
    }
  }'
```

**Response (201):**
```json
{
  "status": "ok",
  "transaction_id": "8b69bd10-...",
  "provider_reference": "fake_b9c57887-..."
}
```

### Idempotency (retry same key → 200)
```json
{
  "status": "already_processed",
  "transaction_id": "8b69bd10-..."
}
```

---

## Key Features

- ✅ **OpenAPI 3.0** — Industry standard
- ✅ **100% coverage** — All 44+ endpoints documented
- ✅ **Interactive UI** — Test APIs directly from browser
- ✅ **Component schemas** — Reusable models (Organization, Transaction, Campaign, etc.)
- ✅ **Security schemes** — JWT + API Key
- ✅ **Gateway Integration** — All transactions route through FakeBaasGateway
- ✅ **Idempotency** — Built-in idempotency key support

---

## Testing API Calls

### Swagger UI
1. Open http://localhost:3000/api-docs
2. Click endpoint → "Try it out" → Fill params → "Execute"

### VS Code REST Client
```http
### List organizations
GET http://localhost:3000/organizations

### Create transaction
POST http://localhost:3000/owners/organization/<org_id>/transactions
Content-Type: application/json

{
  "transaction": {
    "amount_cents": 100000,
    "transaction_type": "credit",
    "idempotency_key": "test-1"
  }
}
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Swagger UI not loading | `rails server -b 0.0.0.0 -p 3000` |
| Can't import in Postman | Import `http://localhost:3000/api-docs/swagger.json` |
| API differs from docs | Regenerate: `RAILS_ENV=test bundle exec rspec spec/requests/api/v1/` |

---

## Coverage

- **Endpoints:** 44+ documented
- **Coverage:** 100% of current system
- **Last Updated:** June 2026
- **Format:** OpenAPI 3.0.0
- **Tool:** Rswag + Swagger UI
