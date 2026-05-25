CREATE TABLE IF NOT EXISTS clareo.transactions_by_owner (
  owner_type text,
  owner_id uuid,
  transaction_id uuid,
  created_at timestamp,
  amount_cents bigint,
  currency text,
  transaction_type text,
  status text,
  campaign_id uuid,
  idempotency_key text,
  external_reference text,
  metadata map<text, text>,
  PRIMARY KEY ((owner_type, owner_id), created_at, transaction_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
