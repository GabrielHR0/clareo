require "securerandom"

module OrganizationsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.organizations (organization_id, name, cnpj, status, contact_email, webhook_url, api_key_hash, owner_user_id, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.organizations WHERE organization_id = ?"
  ALL_CQL = "SELECT * FROM clareo.organizations LIMIT ?"
  GET_BY_API_KEY_CQL = "SELECT * FROM clareo.organizations WHERE api_key_hash = ?"
  FIND_BY_OWNER_CQL = "SELECT * FROM clareo.organizations WHERE owner_user_id = ? LIMIT ? ALLOW FILTERING"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @all    = CassandraClient.session.prepare(ALL_CQL)
    @get_by_api_key = CassandraClient.session.prepare(GET_BY_API_KEY_CQL)
    @find_by_owner = CassandraClient.session.prepare(FIND_BY_OWNER_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:organization_id])
    now = Time.now
    status = attrs[:status] || "active"
    owner_user_id = attrs[:owner_user_id] ? normalize_uuid(attrs[:owner_user_id]) : nil

    CassandraClient.session.execute(@insert, arguments:
      [
        id,
        attrs[:name],
        attrs[:cnpj],
        status,
        attrs[:contact_email],
        attrs[:webhook_url],
        attrs[:api_key_hash],
        owner_user_id,
        now,
        now
      ], consistency: :quorum)

      id
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def all(owner_user_id = nil, limit = 100)
    prepare!
    if owner_user_id
      rows = CassandraClient.session.execute(@find_by_owner, arguments: [normalize_uuid(owner_user_id), limit], consistency: :quorum)
    else
      rows = CassandraClient.session.execute(@all, arguments: [limit], consistency: :quorum)
    end
    rows.map { |r| row_to_hash(r) }
  end

  def find(id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [ normalize_uuid(id) ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def find_by_api_key_hash(hash)
    prepare!
    row = CassandraClient.session.execute(@get_by_api_key, arguments: [hash], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"]&.to_s,
      name: row["name"],
      cnpj: row["cnpj"],
      status: row["status"],
      contact_email: row["contact_email"],
      webhook_url: row["webhook_url"],
      api_key_hash: row["api_key_hash"],
      owner_user_id: row["owner_user_id"]&.to_s,
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
