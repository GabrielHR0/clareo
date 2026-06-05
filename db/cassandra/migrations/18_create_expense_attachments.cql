CREATE TABLE IF NOT EXISTS clareo.expense_attachments (
  organization_id uuid,
  campaign_id uuid,
  entry_id uuid,
  attachment_id uuid,
  filename text,
  original_filename text,
  content_type text,
  file_path text,
  file_size bigint,
  created_at timestamp,
  PRIMARY KEY ((organization_id, campaign_id, entry_id), attachment_id)
);
