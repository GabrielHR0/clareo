CREATE TABLE IF NOT EXISTS clareo.campaigns (
  organization_id uuid,
  campaign_id uuid,
  name text,
  description text,
  goal_cents bigint,
  raised_cents bigint,
  status text,
  starts_at timestamp,
  ends_at timestamp,
  metadata map<text, text>,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY ((organization_id), campaign_id)
);
