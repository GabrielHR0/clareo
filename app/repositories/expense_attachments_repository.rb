require "fileutils"

module ExpenseAttachmentsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.expense_attachments (organization_id, campaign_id, entry_id, attachment_id, filename, original_filename, content_type, file_path, file_size, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.expense_attachments WHERE organization_id = ? AND campaign_id = ? AND entry_id = ? AND attachment_id = ?"
  LIST_CQL = "SELECT * FROM clareo.expense_attachments WHERE organization_id = ? AND campaign_id = ? AND entry_id = ?"
  DELETE_CQL = "DELETE FROM clareo.expense_attachments WHERE organization_id = ? AND campaign_id = ? AND entry_id = ? AND attachment_id = ?"

  STORAGE_ROOT = Rails.root.join("public", "uploads", "accountability")

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def create(org_id, campaign_id, entry_id, uploaded_file)
    prepare!
    att_id = Cassandra::Uuid.new(SecureRandom.uuid)
    org_uuid = normalize_uuid(org_id)
    campaign_uuid = normalize_uuid(campaign_id)
    entry_uuid = normalize_uuid(entry_id)

    ext = File.extname(uploaded_file.original_filename)
    stored_name = "#{att_id}#{ext}"
    relative_path = "#{org_uuid}/#{campaign_uuid}/#{entry_uuid}/#{stored_name}"
    full_path = STORAGE_ROOT.join(relative_path)

    FileUtils.mkdir_p(File.dirname(full_path))
    File.open(full_path, "wb") { |f| f.write(uploaded_file.read) }

    now = Time.now
    CassandraClient.session.execute(@insert, arguments: [
      org_uuid, campaign_uuid, entry_uuid, att_id,
      stored_name, uploaded_file.original_filename,
      uploaded_file.content_type, relative_path,
      uploaded_file.size, now
    ], consistency: :quorum)

    { attachment_id: att_id.to_s, filename: stored_name, original_filename: uploaded_file.original_filename }
  end

  def find(org_id, campaign_id, entry_id, attachment_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id), normalize_uuid(campaign_id),
      normalize_uuid(entry_id), normalize_uuid(attachment_id)
    ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def list(org_id, campaign_id, entry_id)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id), normalize_uuid(campaign_id), normalize_uuid(entry_id)
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def delete(org_id, campaign_id, entry_id, attachment_id)
    prepare!
    org_uuid = normalize_uuid(org_id)
    campaign_uuid = normalize_uuid(campaign_id)
    entry_uuid = normalize_uuid(entry_id)

    record = find(org_uuid, campaign_uuid, entry_uuid, attachment_id)
    if record
      full_path = STORAGE_ROOT.join(record[:file_path])
      File.delete(full_path) if File.exist?(full_path)
    end

    CassandraClient.session.execute(@delete, arguments: [
      org_uuid, campaign_uuid, entry_uuid, normalize_uuid(attachment_id)
    ], consistency: :quorum)
  end

  def file_path(org_id, campaign_id, entry_id, attachment_id)
    record = find(org_id, campaign_id, entry_id, attachment_id)
    return nil unless record
    full = STORAGE_ROOT.join(record[:file_path])
    File.exist?(full) ? full : nil
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
      campaign_id: row["campaign_id"].to_s,
      entry_id: row["entry_id"].to_s,
      filename: row["filename"],
      original_filename: row["original_filename"],
      content_type: row["content_type"],
      file_path: row["file_path"],
      file_size: row["file_size"],
      created_at: row["created_at"]
    }
  end
end
