require "securerandom"

module AuditEventsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.audit_events
      (owner_type, owner_id, event_id, created_at, event_type, payload)
    VALUES (?, ?, ?, ?, ?, ?)
  CQL

  SELECT_BY_OWNER_CQL = <<~CQL
    SELECT * FROM clareo.audit_events
    WHERE owner_type = ? AND owner_id = ?
    ORDER BY created_at DESC
    LIMIT ?
  CQL

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @select_by_owner = CassandraClient.session.prepare(SELECT_BY_OWNER_CQL)
    @prepared = true
  end

  def insert(attrs)
    prepare!
    payload_map = (attrs[:payload] || {}).each_with_object({}) do |(k,v), acc|
      acc[k.to_s] = v.to_s
    end
    CassandraClient.session.execute(
      @insert,
      arguments: [
        attrs[:owner_type].to_s,
        normalize_uuid(attrs[:owner_id]),
        normalize_uuid(attrs[:event_id] || SecureRandom.uuid),
        attrs[:created_at] || Time.now,
        attrs[:event_type],
        payload_map
      ],
      consistency: :quorum
    )
  end

  def find_by_owner(owner_type, owner_id, limit = 100)
    prepare!
    rows = CassandraClient.session.execute(
      @select_by_owner,
      arguments: [ owner_type.to_s, normalize_uuid(owner_id), limit ],
      consistency: :quorum
    )
    rows.map { |r| row_to_hash(r) }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end

  private

  def row_to_hash(row)
    {
      owner_type: row['owner_type'],
      owner_id: row['owner_id'],
      event_id: row['event_id'],
      created_at: row['created_at'],
      event_type: row['event_type'],
      payload: row['payload']
    }
  end
end
