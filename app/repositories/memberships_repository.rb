require "securerandom"

module MembershipsRepository
  extend self

  CREATE_BY_ORG_CQL = <<~CQL
    INSERT INTO clareo.memberships_by_organization (organization_id, contributor_id, membership_id, status, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?)
  CQL

  CREATE_BY_CONTRIBUTOR_CQL = <<~CQL
    INSERT INTO clareo.memberships_by_contributor (contributor_id, organization_id, membership_id, status, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?)
  CQL

  GET_BY_ORG_CQL = "SELECT * FROM clareo.memberships_by_organization WHERE organization_id = ?"
  GET_BY_CONTRIBUTOR_CQL = "SELECT * FROM clareo.memberships_by_contributor WHERE contributor_id = ?"

  def prepare!
    return if @prepared

    @insert_by_org = CassandraClient.session.prepare(CREATE_BY_ORG_CQL)
    @insert_by_contributor = CassandraClient.session.prepare(CREATE_BY_CONTRIBUTOR_CQL)
    @get_by_org = CassandraClient.session.prepare(GET_BY_ORG_CQL)
    @get_by_contributor = CassandraClient.session.prepare(GET_BY_CONTRIBUTOR_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    membership_id = normalize_uuid(attrs[:membership_id])
    organization_id = normalize_uuid(attrs[:organization_id])
    contributor_id = normalize_uuid(attrs[:contributor_id])
    now = Time.now
    status = attrs[:status] || "active"

    CassandraClient.session.execute(
      @insert_by_org,
      arguments: [
        organization_id,
        contributor_id,
        membership_id,
        status,
        now,
        now
      ],
      consistency: :quorum
    )

    CassandraClient.session.execute(
      @insert_by_contributor,
      arguments: [
        contributor_id,
        organization_id,
        membership_id,
        status,
        now,
        now
      ],
      consistency: :quorum
    )

    membership_id
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def for_organization(organization_id)
    prepare!
    rows = CassandraClient.session.execute(@get_by_org, arguments: [ normalize_uuid(organization_id) ], consistency: :quorum)
    rows.map { |row| row_to_hash(row) }
  end

  def for_contributor(contributor_id)
    prepare!
    rows = CassandraClient.session.execute(@get_by_contributor, arguments: [ normalize_uuid(contributor_id) ], consistency: :quorum)
    rows.map { |row| row_to_hash(row) }
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"]&.to_s,
      contributor_id: row["contributor_id"]&.to_s,
      membership_id: row["membership_id"]&.to_s,
      status: row["status"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
