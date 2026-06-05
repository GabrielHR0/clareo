CREATE TABLE IF NOT EXISTS clareo.expense_entries (
  organization_id uuid,
  campaign_id uuid,
  entry_id uuid,
  description text,
  amount_cents bigint,
  category text,
  expense_date date,
  status text,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY ((organization_id, campaign_id), entry_id)
);
