require "securerandom"

module CampaignsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.campaigns (organization_id, campaign_id, name, description, goal_cents, raised_cents, status, starts_at, ends_at, metadata, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.campaigns WHERE organization_id = ? AND campaign_id = ?"
  LIST_CQL = "SELECT * FROM clareo.campaigns WHERE organization_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:campaign_id])
    org_id = normalize_uuid(attrs[:organization_id])
    now = Time.now
    status = attrs[:status] || "draft"

    CassandraClient.session.execute(@insert, arguments:
      [
        org_id,
        id,
        attrs[:name],
        attrs[:description],
        attrs[:goal_cents].to_i,
        attrs[:raised_cents].to_i || 0,
        status,
        attrs[:starts_at],
        attrs[:ends_at],
        attrs[:metadata] || {},
        now,
        now
      ], consistency: :quorum)

    { campaign_id: id, organization_id: org_id }
  end

  def find(org_id, campaign_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id),
      normalize_uuid(campaign_id)
    ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def list(org_id)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id)
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"].to_s,
      campaign_id: row["campaign_id"].to_s,
      name: row["name"],
      description: row["description"],
      goal_cents: row["goal_cents"],
      raised_cents: row["raised_cents"],
      status: row["status"],
      starts_at: row["starts_at"],
      ends_at: row["ends_at"],
      metadata: row["metadata"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
