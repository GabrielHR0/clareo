CREATE TABLE IF NOT EXISTS clareo.ledger_entries_by_owner (
  owner_type text,
  owner_id uuid,
  entry_id uuid,
  created_at timestamp,
  transaction_id uuid,
  entry_type text,
  account text,
  amount_cents bigint,
  balance_after_cents bigint,
  description text,
  PRIMARY KEY ((owner_type, owner_id), created_at, entry_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
