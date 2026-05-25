CREATE TABLE IF NOT EXISTS clareo.audit_events (
  owner_type text,
  owner_id uuid,
  event_id uuid,
  created_at timestamp,
  event_type text,
  payload map<text, text>,
  PRIMARY KEY ((owner_type, owner_id), created_at, event_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
