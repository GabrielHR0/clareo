# FakeBaasGateway: Centralized Payment Processing

## Overview

The `FakeBaasGateway` is a centralized payment processing abstraction that simulates a real Banking-as-a-Service (SaaS) provider. All transaction types—**credits**, **debits**, and **transfers**—route through this gateway to enable realistic simulation of external provider integration.

## Architecture

### Core Design Principles

1. **SaaS Provider Simulation**: FakeBaasGateway acts as an external payment processor with its own state management.
2. **Single Source of Truth**: All payment operations (`authorize`, `capture`, `refund`, `transfer`, `hold`, `release_hold`) are managed by the gateway.
3. **Idempotency**: Operations are idempotent at both gateway and application levels (via idempotency keys).
4. **Audit Trail**: All gateway operations are logged to Cassandra and published to Kafka for compliance and analytics.

### File Location

```
lib/fake_baas_gateway.rb    # Centralized gateway module (auto-loaded by Rails)
```

**Why `lib/`?** Rails' `config.autoload_lib(ignore: %w[assets tasks])` ensures the gateway is loaded on first use and reloaded in development mode.

## Transaction Flow

### Single Transactions (Credit/Debit)

```
1. ProcessTransactionService.call(type: "credit"/"debit", ...)
2. FakeBaasGateway.authorize(amount_cents, ...)
   └─ Returns: { provider_reference, status: "authorized" }
3. Apply wallet updates locally (with LWT-style version check)
4. FakeBaasGateway.capture(provider_reference)
   └─ Returns: { status: "captured" }
5. Record transaction to Cassandra, publish audit event
```

### Transfer Transactions

```
1. ProcessTransactionService.call(type: "transfer", dest_owner_type, dest_owner_id)
2. FakeBaasGateway.transfer(amount_cents, source, destination, ...)
   └─ Holds funds on source wallet in gateway state
   └─ Returns: { provider_reference, source_hold_id, status: "authorized" }
3. Attempt local debit from source wallet
4. Attempt local credit to destination wallet
5. FakeBaasGateway.complete_transfer(provider_reference)
   └─ Finalizes the transfer in gateway state
6. Record transactions (source + destination), publish audit events

# Compensation on Failure:
   If credit destination fails:
   ├─ FakeBaasGateway.reverse_transfer(provider_reference)
   ├─ Refund source wallet (compensate_source_after_failed_credit)
   └─ Log compensation event
```

## Gateway Methods

### Authorization & Capture

#### `FakeBaasGateway.authorize(amount_cents:, currency:, owner_type:, owner_id:, metadata:)`

- **Purpose**: Reserve funds without immediate transfer (simulates external provider authorization)
- **Returns**: `{ provider_reference, status: "authorized", timestamp }`
- **State**: Stored in `@@transactions` class variable (in-memory)

#### `FakeBaasGateway.capture(provider_reference:)`

- **Purpose**: Confirm previously authorized amount (convert hold to actual charge)
- **Returns**: `{ status: "captured", provider_reference }`
- **State**: Moves transaction from "authorized" to "captured" in `@@transactions`

### Refunds

#### `FakeBaasGateway.refund(provider_reference:, amount_cents:)`

- **Purpose**: Reverse a captured transaction (full or partial refund)
- **Returns**: `{ status: "refunded", refund_reference, amount_cents }`
- **Precondition**: Original transaction must be "captured"

### Holds & Releases

#### `FakeBaasGateway.hold(amount_cents:, owner_type:, owner_id:, metadata:)`

- **Purpose**: Place a temporary hold on funds (for multi-step operations)
- **Returns**: `{ status: "held", hold_id, amount_cents, owner_id }`
- **State**: Stored in `@@holds` class variable

#### `FakeBaasGateway.release_hold(hold_reference:)`

- **Purpose**: Release a hold (funds become available again)
- **Returns**: `{ status: "released", hold_reference }`

### Transfers

#### `FakeBaasGateway.transfer(amount_cents:, source_owner_type:, source_owner_id:, dest_owner_type:, dest_owner_id:, ...)`

- **Purpose**: Initiate a bilateral transfer (simulates p2p or inter-account movement)
- **Returns**: 
  ```ruby
  {
    provider_reference: "fake_transfer_<uuid>",
    source_hold_id: "<uuid>",
    status: "authorized",
    timestamp
  }
  ```
- **State**: Creates transaction + hold in gateway state; source hold prevents double-spend

#### `FakeBaasGateway.complete_transfer(transfer_reference:)`

- **Purpose**: Finalize transfer after local wallet updates succeed
- **Returns**: `{ status: "captured", provider_reference }`
- **State**: Releases source hold, marks transfer as "captured"

#### `FakeBaasGateway.reverse_transfer(transfer_reference:)`

- **Purpose**: Undo a transfer (called when local credit destination fails, or on explicit cancellation)
- **Returns**: `{ status: "reversed", provider_reference }`
- **State**: Releases source hold, marks transfer as "reversed"

### Debug Methods

#### `FakeBaasGateway.get_transaction(provider_reference:)`
- Look up transaction by provider reference

#### `FakeBaasGateway.get_hold(hold_reference:)`
- Look up hold by hold reference

## State Management

### In-Memory State (Development/Testing)

```ruby
# lib/fake_baas_gateway.rb

@@transactions = {
  "fake_<uuid_1>" => { 
    provider_reference: "fake_<uuid_1>", 
    status: "captured",
    amount_cents: 1000,
    owner_type: "organization",
    owner_id: "<uuid>",
    # ...
  },
  # ...
}

@@holds = {
  "hold_<uuid>" => { 
    hold_id: "hold_<uuid>", 
    status: "held",
    amount_cents: 500,
    owner_id: "<uuid>",
    # ...
  }
}
```

**Note**: In production, replace `@@transactions` and `@@holds` with calls to real provider APIs (Stripe, PayPal, etc.).

## Integration with Application Services

### ProcessTransactionService

- **Single Txns**: Calls `authorize` → local wallet update → `capture`
- **Transfers**: Calls `transfer` → local debit → local credit → `complete_transfer`
- **Audit Logging**: All gateway calls logged via centralized `AuditLogger.log()`

```ruby
# app/services/process_transaction_service.rb

require "fake_baas_gateway"

case @transaction_type
when "credit"
  gateway_resp = FakeBaasGateway.authorize(...)
  apply_single_wallet_flow(tx_id, gateway_resp)
when "transfer"
  gateway_resp = FakeBaasGateway.transfer(...)
  handle_transfer(tx_id)
end
```

### Audit Logger

- **Purpose**: Centralized audit event recording for compliance
- **Destinations**: 
  - Cassandra `audit_events` table
  - Kafka `audit.events` topic (for real-time message bus)

```ruby
# app/services/audit_logger.rb

AuditLogger.log(
  owner_type: "organization",
  owner_id: "<uuid>",
  event_type: "transfer_initiated_by_gateway",
  payload: { transfer_reference: "fake_transfer_<uuid>" }
)
```

## Testing

### Unit Tests

Test individual gateway methods:

```ruby
# spec/unit/fake_baas_gateway_spec.rb

it "authorizes and captures funds" do
  auth = FakeBaasGateway.authorize(amount_cents: 1000, ...)
  expect(auth[:status]).to eq("authorized")
  
  capture = FakeBaasGateway.capture(provider_reference: auth[:provider_reference])
  expect(capture[:status]).to eq("captured")
end
```

### Integration Tests

Test full transaction flows (see [spec/integration/gateway_centralization_spec.rb](../../spec/integration/gateway_centralization_spec.rb)):

- ✅ Credits route through gateway
- ✅ Debits route through gateway
- ✅ Transfers orchestrated at gateway + local wallet level
- ✅ Insufficient funds prevented by gateway hold
- ✅ Idempotency respected across retries
- ✅ Audit events logged for all operations

Run:
```bash
RAILS_ENV=test bundle exec rspec spec/integration/gateway_centralization_spec.rb -v
```

## Migration to Real Provider

### Step 1: Create Provider Adapter

```ruby
# lib/stripe_baas_gateway.rb (example)

module StripeBaasGateway
  extend self

  def authorize(amount_cents:, currency:, **opts)
    charge = Stripe::PaymentIntent.create(
      amount: amount_cents,
      currency: currency,
      payment_method: opts[:payment_method_id],
      confirmation_method: "manual"
    )
    { 
      provider_reference: charge.id, 
      status: "authorized",
      timestamp: Time.now 
    }
  rescue Stripe::CardError => e
    { status: "failed", error: e.message }
  end
  
  # ... other methods
end
```

### Step 2: Update ProcessTransactionService

```ruby
# app/services/process_transaction_service.rb

GATEWAY = ENV["PAYMENT_GATEWAY"] == "stripe" ? StripeBaasGateway : FakeBaasGateway

# Replace all FakeBaasGateway calls:
gateway_resp = GATEWAY.authorize(...)
```

### Step 3: Environment Configuration

```bash
# .env.production
PAYMENT_GATEWAY=stripe
STRIPE_API_KEY=sk_live_...
```

## Logging & Debugging

### View Gateway State

```ruby
# Rails console
FakeBaasGateway.get_transaction(provider_reference: "fake_transfer_...")
FakeBaasGateway.get_hold(hold_reference: "hold_...")
```

### Audit Events

```ruby
# Query Cassandra
AuditEventsRepository.find_by_owner("organization", owner_id, limit: 50)

# Subscribe to Kafka
# (See Kafka setup in docs/05_KAFKA_STRATEGY.md)
```

## Compliance & Audit Trail

All gateway operations are immutably logged:

| Gateway Call | Audit Event | Cassandra Table | Kafka Topic |
|---|---|---|---|
| `authorize` | `payment_authorized_by_gateway` | audit_events | audit.events |
| `capture` | `transfer_completed` / `transaction_recorded` | audit_events | audit.events |
| `transfer` | `transfer_initiated_by_gateway` | audit_events | audit.events |
| `complete_transfer` | `transfer_completed` | audit_events | audit.events |
| `reverse_transfer` | `transfer_reversed_...` | audit_events | audit.events |

This ensures compliance, debugging, and forensic auditing regardless of the underlying gateway provider.

## References

- [ProcessTransactionService](../app/services/process_transaction_service.rb)
- [AuditLogger](../app/services/audit_logger.rb)
- [FakeBaasGateway](../lib/fake_baas_gateway.rb)
- [Integration Tests](../spec/integration/gateway_centralization_spec.rb)
- [Architecture Documentation](./02_ARQUITETURA.md)
- [Kafka Strategy](./05_KAFKA_STRATEGY.md)
