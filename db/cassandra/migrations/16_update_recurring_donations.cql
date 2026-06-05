ALTER TABLE clareo.recurring_donations ADD status text;
ALTER TABLE clareo.recurring_donations ADD start_date timestamp;
ALTER TABLE clareo.recurring_donations ADD end_date timestamp;
ALTER TABLE clareo.recurring_donations ADD campaign_id uuid;

CREATE INDEX IF NOT EXISTS idx_recurring_contributor ON clareo.recurring_donations (contributor_id);
