CREATE TABLE clareo.organizations (
    organization_id UUID PRIMARY KEY,
    name TEXT,
    cnpj TEXT,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    contact_email TEXT,
    webhook_url TEXT,
    api_key_hash TEXT
);

CREATE INDEX inx_cnpj
ON clareo.organizations (cnpj);

CREATE INDEX inx_status
ON clareo.organizations (status);