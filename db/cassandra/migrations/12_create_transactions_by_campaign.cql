CREATE TABLE IF NOT EXISTS clareo.transactions_by_campaign (
  campaign_id uuid,
  created_at timestamp,
  transaction_id uuid,
  owner_type text,
  owner_id uuid,
  amount_cents bigint,
  currency text,
  transaction_type text,
  status text,
  idempotency_key text,
  external_reference text,
  metadata map<text, text>,
  PRIMARY KEY ((campaign_id), created_at, transaction_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
