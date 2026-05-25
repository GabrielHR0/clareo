CREATE TABLE IF NOT EXISTS clareo.recurring_donations (
  organization_id uuid,
  contributor_id uuid,
  recurring_id uuid,
  amount_cents bigint,
  currency text,
  payment_method text,
  card_reference text,
  interval_days int,
  next_charge_date date,
  created_at timestamp,
  PRIMARY KEY ((organization_id), contributor_id, recurring_id)
);

CREATE INDEX IF NOT EXISTS idx_recurring_next_charge ON clareo.recurring_donations (next_charge_date);
