CREATE TABLE IF NOT EXISTS clareo.idempotency_keys_by_owner (
  owner_type text,
  owner_id uuid,
  idempotency_key text,
  transaction_id uuid,
  request_hash text,
  created_at timestamp,
  expires_at timestamp,
  PRIMARY KEY ((owner_type, owner_id), idempotency_key)
);
