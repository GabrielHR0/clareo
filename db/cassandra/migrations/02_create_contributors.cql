CREATE TABLE IF NOT EXISTS clareo.contributors (
    contributor_id UUID PRIMARY KEY,
    name TEXT,
    email TEXT,
    cpf TEXT,
    phone TEXT,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS inx_contributor_email
ON clareo.contributors (email);

CREATE INDEX IF NOT EXISTS inx_contributor_cpf
ON clareo.contributors (cpf);
