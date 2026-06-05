require "securerandom"

module ContributorsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.contributors (contributor_id, name, email, cpf, phone, status, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.contributors WHERE contributor_id = ?"
  ALL_CQL = "SELECT * FROM clareo.contributors LIMIT ?"

  def prepare!
    return if @prepared

    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get = CassandraClient.session.prepare(GET_CQL)
    @all = CassandraClient.session.prepare(ALL_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:contributor_id])
    now = Time.now
    status = attrs[:status] || "active"

    result = CassandraClient.session.execute(
      @insert,
      arguments: [
        id,
        attrs[:name],
        attrs[:email],
        attrs[:cpf],
        attrs[:phone],
        status,
        now,
        now
      ],
      consistency: :quorum
    )

      id
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def all(limit = 100)
    prepare!
    rows = CassandraClient.session.execute(@all, arguments: [limit], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def find(id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [ normalize_uuid(id) ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def row_to_hash(row)
    {
      contributor_id: row["contributor_id"],
      name: row["name"],
      email: row["email"],
      cpf: row["cpf"],
      phone: row["phone"],
      status: row["status"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
