# API Documentation - Swagger/OpenAPI

## Overview

Clareo API is fully documented using OpenAPI 3.0 (Swagger) specification. The interactive documentation allows you to explore all endpoints, see request/response examples, and test the API directly from your browser.

## Accessing the Documentation

### Interactive Swagger UI (Recommended)

Once Rails server is running, visit:

```
http://localhost:3000/api-docs
```

This provides an interactive interface where you can:
- Browse all endpoints organized by resource
- View request/response schemas
- Try out API calls in real-time
- See response codes and examples

### OpenAPI/Swagger JSON

The raw OpenAPI specification is available at:

```
http://localhost:3000/api-docs/swagger.json
```

### API Versioning

All business endpoints are versioned under `/api/v1`.
Examples:
- `GET /api/v1/organizations`
- `POST /api/v1/owners/{owner_type}/{owner_id}/transactions`
- `GET /api/v1/campaigns/{campaign_id}/transactions`

You can import this into tools like:
- [Postman](https://www.postman.com/)
- [Insomnia](https://insomnia.rest/)
- [VS Code REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

## API Endpoints Summary (24 Endpoints Total)

### Health (2 endpoints)
- `GET /up` — Rails health check
- `GET /health/cassandra` — Cassandra database health

### Organizations (3 endpoints)
- `GET /organizations` — List all organizations
- `POST /organizations` — Create new organization
- `GET /organizations/{id}` — Get organization details

### Contributors (3 endpoints)
- `GET /contributors` — List all contributors
- `POST /contributors` — Create new contributor
- `GET /contributors/{id}` — Get contributor details

### Memberships (2 endpoints)
- `GET /memberships` — List all memberships
- `POST /memberships` — Create new membership

### Wallets (2 endpoints)
- `GET /owners/{owner_type}/{owner_id}/wallet` — Get wallet
- `POST /owners/{owner_type}/{owner_id}/wallet` — Create wallet

### Transactions (4 endpoints) ⭐ **Core API**
- `POST /owners/{owner_type}/{owner_id}/transactions` — Create transaction (via FakeBaasGateway)
- `GET /owners/{owner_type}/{owner_id}/transactions` — List owner transactions
- `GET /owners/{owner_type}/{owner_id}/transactions/{id}` — Get transaction details
- `GET /campaigns/{campaign_id}/transactions` — List campaign transactions

### Payment Methods (1 endpoint)
- `POST /owners/{owner_type}/{owner_id}/payment_methods` — Create payment method

### Credit Lines (4 endpoints)
- `GET /credit_lines` — List all credit lines
- `POST /credit_lines` — Create credit line
- `GET /credit_lines/{id}` — Get credit line details
- `POST /credit_lines/{id}/use` — Draw on credit line

## Transaction Flow Examples

### Credit Example
```bash
curl -X POST http://localhost:3000/owners/organization/550e8400-e29b-41d4-a716-446655440000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "amount_cents": 100000,
      "currency": "BRL",
      "transaction_type": "credit",
      "idempotency_key": "credit-unique-key-123"
    }
  }'
```

**Response (201 Created):**
```json
{
  "status": "ok",
  "transaction_id": "8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e",
  "provider_reference": "fake_b9c57887-ab58-461c-bbf0-688bc9125eb4"
}
```

### Transfer Example
```bash
curl -X POST http://localhost:3000/owners/organization/550e8400-e29b-41d4-a716-446655440000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "amount_cents": 50000,
      "currency": "BRL",
      "transaction_type": "transfer",
      "idempotency_key": "transfer-unique-key-456",
      "dest_owner_type": "organization",
      "dest_owner_id": "2d7e1533-83c2-4310-874b-c43cd0c727f1"
    }
  }'
```

**Response (201 Created):**
```json
{
  "status": "ok",
  "transaction_id": "bc5749b8-b074-4da1-86ea-b55779ab2b7c",
  "transfer_id": "5a4bc0e3-2b36-4a7d-afda-537e544457e9",
  "provider_reference": "fake_transfer_47a2fb4d-9bf5-4b20-a162-d74bb78c400f"
}
```

### Idempotency Example (Retry with same key)
```bash
# Same request again with identical idempotency_key
curl -X POST http://localhost:3000/owners/organization/550e8400-e29b-41d4-a716-446655440000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "amount_cents": 100000,
      "currency": "BRL",
      "transaction_type": "credit",
      "idempotency_key": "credit-unique-key-123"
    }
  }'
```

**Response (200 OK - Not duplicated):**
```json
{
  "status": "already_processed",
  "transaction_id": "8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e"
}
```

## Key Features

### ✅ 100% Coverage
All 24 current API endpoints documented with:
- Complete request/response schemas
- Example payloads for each scenario
- HTTP status codes (201, 200, 400, 404, 409, etc)
- Error handling documentation

### ✅ Production-Ready
- OpenAPI 3.0 standard (industry standard)
- Clear descriptions for every endpoint
- Server configuration for dev/staging/prod
- Component schemas for reusability

### ✅ Gateway Integration
All transaction endpoints route through **FakeBaasGateway**:
- `authorize()` — Reserve funds
- `capture()` — Confirm charge
- `transfer()` — Bilateral p2p movement  
- Idempotency enforcement at all levels

### ✅ Type Safety
Complete JSON schema validation:
- Required fields enforcement
- Enum type validation
- UUID format validation
- Integer/string/object type constraints

## Environment-Specific Documentation

Switch between servers in Swagger UI dropdown:
- **Development**: `http://localhost:3000`
- **Staging**: `https://staging-api.clareo.io`
- **Production**: `https://api.clareo.io`

## Authentication (Future Implementation)

The API documentation includes placeholders for two auth schemes:
- **API Key** (`X-API-Key` header)
- **Bearer Token** (HTTP Bearer scheme)

Configure in `.env`:
```bash
API_AUTH_TYPE=bearer_token  # or api_key
API_KEY_HEADER_NAME=X-API-Key
```

## Testing API Calls

### Using Swagger UI (Browser)
1. Open http://localhost:3000/api-docs
2. Click on any endpoint
3. Click "Try it out"
4. Fill in parameters
5. Click "Execute"
6. See response immediately

### Using cURL (CLI)
```bash
curl -X GET http://localhost:3000/organizations
curl -X POST http://localhost:3000/organizations \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Org"}'
```

### Using Postman
1. Import: `http://localhost:3000/api-docs/swagger.json`
2. Create new request
3. Select method and endpoint
4. Set parameters/body
5. Send request

### Using VS Code REST Client
Create `.http` file:
```http
### List organizations
GET http://localhost:3000/organizations

### Create transaction
POST http://localhost:3000/owners/organization/550e8400-e29b-41d4-a716-446655440000/transactions
Content-Type: application/json

{
  "transaction": {
    "amount_cents": 100000,
    "currency": "BRL",
    "transaction_type": "credit",
    "idempotency_key": "credit-test-1"
  }
}
```

## Troubleshooting

### Swagger UI not loading?
```bash
# Ensure Rails server is running:
RAILS_ENV=development bin/rails server -b 0.0.0.0 -p 3000

# Check logs for errors:
tail -f log/development.log
```

### Can't import into Postman?
1. Try URL: http://localhost:3000/api-docs/swagger.json
2. Or download the JSON and import as file

### API response different from docs?
1. Regenerate documentation with: `RAILS_ENV=test rspec spec/requests/api/v1/`
2. or Manually verify against latest swagger.json

## API Status & Support

- **Endpoints**: 24 documented
- **Coverage**: 100% of current system
- **Last Updated**: May 25, 2026
- **Format Version**: OpenAPI 3.0.0
- **Tools**: Rswag + Swagger UI

For bug reports or feature requests, visit: https://github.com/clareo/clareo-api/issues

---

**Next Step**: Start the Rails server and visit http://localhost:3000/api-docs to explore the interactive documentation!
