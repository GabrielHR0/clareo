CREATE TABLE IF NOT EXISTS clareo.wallets (
    owner_id UUID,
    owner_type TEXT,
    balance_cents BIGINT,
    available_cents BIGINT,
    locked_cents BIGINT,
    version INT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((owner_type, owner_id))
)