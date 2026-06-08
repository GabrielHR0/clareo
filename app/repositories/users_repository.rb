module UsersRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.users (user_id, email, password_hash, name, contributor_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.users WHERE user_id = ?"
  GET_BY_EMAIL_CQL = "SELECT * FROM clareo.users WHERE email = ?"
  GET_BY_CONTRIBUTOR_CQL = "SELECT * FROM clareo.users WHERE contributor_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get = CassandraClient.session.prepare(GET_CQL)
    @get_by_email = CassandraClient.session.prepare(GET_BY_EMAIL_CQL)
    @get_by_contributor = CassandraClient.session.prepare(GET_BY_CONTRIBUTOR_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = attrs[:user_id] ? normalize_uuid(attrs[:user_id]) : Cassandra::Uuid.new(SecureRandom.uuid)
    contributor_id = attrs[:contributor_id] ? normalize_uuid(attrs[:contributor_id]) : nil
    now = Time.now

    CassandraClient.session.execute(@insert, arguments: [
      id,
      attrs[:email],
      attrs[:password_hash],
      attrs[:name],
      contributor_id,
      now,
      now
    ], consistency: :quorum)

    id
  end

  def update(user_id, attrs)
    prepare!
    now = Time.now
    existing = find(user_id)
    return nil unless existing

    merged = existing.merge(attrs).merge(updated_at: now)
    merged[:user_id] = normalize_uuid(merged[:user_id])
    merged[:contributor_id] = merged[:contributor_id] ? normalize_uuid(merged[:contributor_id]) : nil

    CassandraClient.session.execute(@insert, arguments: [
      merged[:user_id],
      merged[:email],
      merged[:password_hash],
      merged[:name],
      merged[:contributor_id],
      merged[:created_at],
      merged[:updated_at]
    ], consistency: :quorum)

    find(user_id)
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

  def find_by_contributor_id(contributor_id)
    prepare!
    row = CassandraClient.session.execute(@get_by_contributor, arguments: [normalize_uuid(contributor_id)], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    return if value.nil?
    Cassandra::Uuid.new(value)
  end

  def row_to_hash(row)
    {
      user_id: row["user_id"]&.to_s,
      email: row["email"],
      password_hash: row["password_hash"],
      name: row["name"],
      contributor_id: row["contributor_id"]&.to_s,
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
