CREATE TABLE IF NOT EXISTS clareo.memberships_by_organization (
    organization_id UUID,
    contributor_id UUID,
    membership_id UUID,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((organization_id), contributor_id)
) WITH CLUSTERING ORDER BY (contributor_id ASC);

CREATE TABLE IF NOT EXISTS clareo.memberships_by_contributor (
    contributor_id UUID,
    organization_id UUID,
    membership_id UUID,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((contributor_id), organization_id)
) WITH CLUSTERING ORDER BY (organization_id ASC);
