CREATE TABLE IF NOT EXISTS clareo.post_comments (
    post_id UUID,
    comment_id UUID,
    author_id UUID,
    author_type TEXT,
    author_name TEXT,
    content TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY ((post_id), created_at, comment_id)
) WITH CLUSTERING ORDER BY (created_at DESC);
