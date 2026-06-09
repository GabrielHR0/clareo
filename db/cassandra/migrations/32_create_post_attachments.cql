CREATE TABLE IF NOT EXISTS clareo.post_attachments (
    organization_id UUID,
    post_id UUID,
    attachment_id UUID,
    filename TEXT,
    original_filename TEXT,
    content_type TEXT,
    file_path TEXT,
    file_size BIGINT,
    created_at TIMESTAMP,
    PRIMARY KEY ((organization_id, post_id), attachment_id)
);
