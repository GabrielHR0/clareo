CREATE TABLE IF NOT EXISTS clareo.credit_bills (
    organization_id UUID,
    bill_id UUID,
    credit_id UUID,
    due_date DATE,
    amount_cents BIGINT,
    paid_cents BIGINT,
    status TEXT,
    created_at TIMESTAMP,
    paid_at TIMESTAMP,
    PRIMARY KEY ((organization_id), bill_id)
);

CREATE INDEX IF NOT EXISTS idx_credit_bills_status ON clareo.credit_bills (status);
