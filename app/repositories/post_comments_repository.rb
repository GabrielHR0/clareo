module PostCommentsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.post_comments (post_id, comment_id, author_id, author_type, author_name, content, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  CQL

  LIST_CQL = "SELECT * FROM clareo.post_comments WHERE post_id = ? LIMIT ?"
  GET_CQL = "SELECT * FROM clareo.post_comments WHERE post_id = ? AND created_at = ? AND comment_id = ?"
  DELETE_CQL = "DELETE FROM clareo.post_comments WHERE post_id = ? AND comment_id = ?"

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
    comment_id = normalize_uuid(attrs[:comment_id])
    post_id = normalize_uuid(attrs[:post_id])
    now = Time.now.utc

    CassandraClient.session.execute(@insert, arguments: [
      post_id, comment_id,
      normalize_uuid(attrs[:author_id]),
      attrs[:author_type],
      attrs[:author_name],
      attrs[:content],
      now
    ], consistency: :quorum)

    { comment_id: comment_id.to_s, post_id: post_id.to_s }
  end

  def list(post_id, limit = 50)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(post_id), limit
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def find(post_id, comment_id)
    prepare!
    rows = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(post_id), Time.now.utc, normalize_uuid(comment_id)
    ], consistency: :quorum)
    row = rows.first
    row && row_to_hash(row)
  end

  def delete(post_id, comment_id)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [
      normalize_uuid(post_id), normalize_uuid(comment_id)
    ], consistency: :quorum)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      comment_id: row["comment_id"].to_s,
      post_id: row["post_id"].to_s,
      author_id: row["author_id"]&.to_s,
      author_type: row["author_type"],
      author_name: row["author_name"],
      content: row["content"],
      created_at: row["created_at"]
    }
  end
end
