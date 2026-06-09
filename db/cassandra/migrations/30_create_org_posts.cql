CREATE TABLE IF NOT EXISTS clareo.org_posts (
    organization_id UUID,
    post_id UUID,
    author_id UUID,
    author_type TEXT,
    author_name TEXT,
    content TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((organization_id), created_at, post_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
