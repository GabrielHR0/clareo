module OrgPostsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.org_posts (organization_id, post_id, author_id, author_type, author_name, content, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  LIST_CQL = "SELECT * FROM clareo.org_posts WHERE organization_id = ? LIMIT ?"
  GET_CQL = "SELECT * FROM clareo.org_posts WHERE organization_id = ? AND created_at = ? AND post_id = ?"
  DELETE_CQL = "DELETE FROM clareo.org_posts WHERE organization_id = ? AND post_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    post_id = normalize_uuid(attrs[:post_id])
    org_id = normalize_uuid(attrs[:organization_id])
    now = Time.now.utc

    CassandraClient.session.execute(@insert, arguments: [
      org_id, post_id,
      normalize_uuid(attrs[:author_id]),
      attrs[:author_type],
      attrs[:author_name],
      attrs[:content],
      attrs[:created_at] || now,
      now
    ], consistency: :quorum)

    { post_id: post_id.to_s, organization_id: org_id.to_s }
  end

  def list(org_id, limit = 50)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id), limit
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def find(org_id, post_id)
    prepare!
    rows = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id), Time.now.utc, normalize_uuid(post_id)
    ], consistency: :quorum)
    row = rows.first
    row && row_to_hash(row)
  end

  def delete(org_id, post_id)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [
      normalize_uuid(org_id), normalize_uuid(post_id)
    ], consistency: :quorum)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      post_id: row["post_id"].to_s,
      organization_id: row["organization_id"].to_s,
      author_id: row["author_id"]&.to_s,
      author_type: row["author_type"],
      author_name: row["author_name"],
      content: row["content"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
