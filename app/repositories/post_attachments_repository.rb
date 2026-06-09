require "fileutils"

module PostAttachmentsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.post_attachments (organization_id, post_id, attachment_id, filename, original_filename, content_type, file_path, file_size, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  LIST_CQL = "SELECT * FROM clareo.post_attachments WHERE organization_id = ? AND post_id = ?"
  DELETE_CQL = "DELETE FROM clareo.post_attachments WHERE organization_id = ? AND post_id = ? AND attachment_id = ?"

  STORAGE_ROOT = Rails.root.join("public", "uploads", "posts")

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def create(org_id, post_id, uploaded_file)
    prepare!
    att_id = Cassandra::Uuid.new(SecureRandom.uuid)
    org_uuid = normalize_uuid(org_id)
    post_uuid = normalize_uuid(post_id)

    ext = File.extname(uploaded_file.original_filename)
    stored_name = "#{att_id}#{ext}"
    relative_path = "#{org_uuid}/#{post_uuid}/#{stored_name}"
    full_path = STORAGE_ROOT.join(relative_path)

    FileUtils.mkdir_p(File.dirname(full_path))
    File.open(full_path, "wb") { |f| f.write(uploaded_file.read) }

    now = Time.now
    CassandraClient.session.execute(@insert, arguments: [
      org_uuid, post_uuid, att_id,
      stored_name, uploaded_file.original_filename,
      uploaded_file.content_type, relative_path,
      uploaded_file.size, now
    ], consistency: :quorum)

    { attachment_id: att_id.to_s, filename: stored_name, original_filename: uploaded_file.original_filename }
  end

  def list(org_id, post_id)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id), normalize_uuid(post_id)
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def delete(org_id, post_id, attachment_id)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [
      normalize_uuid(org_id), normalize_uuid(post_id), normalize_uuid(attachment_id)
    ], consistency: :quorum)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      attachment_id: row["attachment_id"].to_s,
      organization_id: row["organization_id"].to_s,
      post_id: row["post_id"].to_s,
      filename: row["filename"],
      original_filename: row["original_filename"],
      content_type: row["content_type"],
      file_path: row["file_path"],
      file_size: row["file_size"],
      created_at: row["created_at"]
    }
  end
end
