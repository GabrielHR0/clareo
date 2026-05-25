/* 09_create_credit_lines.cql
   Create table for credit lines (system of credit)
*/

CREATE TABLE IF NOT EXISTS clareo.credit_lines (
  credit_id UUID PRIMARY KEY,
  organization_id UUID,
  limit_cents BIGINT,
  used_cents BIGINT,
  available_cents BIGINT,
  annual_rate DECIMAL,
  status TEXT,
  created_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_credit_org ON clareo.credit_lines (organization_id);
