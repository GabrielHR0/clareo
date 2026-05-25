require "securerandom"

module OrganizationsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.organizations (organization_id, name, cnpj, status, contact_email, webhook_url, api_key_hash, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.organizations WHERE organization_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:organization_id])
    now = Time.now
    status = attrs[:status] || "active"

    result = CassandraClient.session.execute(@insert, arguments:
      [
        id,
        attrs[:name],
        attrs[:cnpj],
        status,
        attrs[:contact_email],
        attrs[:webhook_url],
        attrs[:api_key_hash],
        now,
        now
      ], consistency: :quorum)

      id
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def find(id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [ id ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"],
      name: row["name"],
      cnpj: row["cnpj"],
      status: row["status"],
      contact_email: row["contact_email"],
      webhook_url: row["webhook_url"],
      api_key_hash: row["api_key_hash"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
