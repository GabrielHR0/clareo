CREATE TABLE IF NOT EXISTS clareo.campaigns_by_tag (
  tag text,
  campaign_id uuid,
  organization_id uuid,
  name text,
  cover_url text,
  cover_color text,
  goal_cents bigint,
  raised_cents bigint,
  status text,
  PRIMARY KEY ((tag), campaign_id)
);
