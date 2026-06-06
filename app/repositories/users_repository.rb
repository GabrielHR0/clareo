module UsersRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.users (user_id, email, password_hash, name, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.users WHERE user_id = ?"
  GET_BY_EMAIL_CQL = "SELECT * FROM clareo.users WHERE email = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get = CassandraClient.session.prepare(GET_CQL)
    @get_by_email = CassandraClient.session.prepare(GET_BY_EMAIL_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:user_id])
    now = Time.now

    CassandraClient.session.execute(@insert, arguments: [
      id,
      attrs[:email],
      attrs[:password_hash],
      attrs[:name],
      now,
      now
    ], consistency: :quorum)

    id
  end

  def find(id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [normalize_uuid(id)], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def find_by_email(email)
    prepare!
    row = CassandraClient.session.execute(@get_by_email, arguments: [email], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def row_to_hash(row)
    {
      user_id: row["user_id"]&.to_s,
      email: row["email"],
      password_hash: row["password_hash"],
      name: row["name"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
