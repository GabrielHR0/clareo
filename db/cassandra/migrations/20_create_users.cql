CREATE TABLE IF NOT EXISTS clareo.users (
    user_id UUID PRIMARY KEY,
    email TEXT,
    password_hash TEXT,
    name TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON clareo.users (email);
