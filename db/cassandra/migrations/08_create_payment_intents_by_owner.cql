CREATE TABLE IF NOT EXISTS clareo.payment_intents_by_owner (
  owner_type text,
  owner_id uuid,
  payment_intent_id uuid,
  amount_cents bigint,
  campaign_id uuid,
  status text,
  provider text,
  provider_reference text,
  authorized_at timestamp,
  captured_at timestamp,
  failed_reason text,
  created_at timestamp,
  PRIMARY KEY ((owner_type, owner_id), payment_intent_id)
);
