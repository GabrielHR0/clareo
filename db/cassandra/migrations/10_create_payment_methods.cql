CREATE TABLE IF NOT EXISTS clareo.payment_methods (
  owner_type text,
  owner_id uuid,
  method_id uuid,
  method_type text,
  details map<text, text>,
  is_default boolean,
  created_at timestamp,
  PRIMARY KEY ((owner_type, owner_id), method_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_owner ON clareo.payment_methods (owner_id);
