ALTER TABLE clareo.users ADD contributor_id UUID;
CREATE INDEX IF NOT EXISTS idx_users_contributor ON clareo.users (contributor_id);
