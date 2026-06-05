CREATE TABLE IF NOT EXISTS clareo.campaigns_by_id (
  campaign_id uuid,
  organization_id uuid,
  name text,
  PRIMARY KEY (campaign_id)
);
