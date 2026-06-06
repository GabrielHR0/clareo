require "securerandom"

module TransactionsByOwnerRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.transactions_by_owner
      (owner_type, owner_id, transaction_id, created_at, amount_cents, currency, transaction_type, status, campaign_id, idempotency_key, external_reference, metadata)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  SELECT_BY_OWNER_CQL = <<~CQL
    SELECT * FROM clareo.transactions_by_owner
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
    CassandraClient.session.execute(
      @insert,
      arguments: [
        attrs[:owner_type].to_s,
        normalize_uuid(attrs[:owner_id]),
        normalize_uuid(attrs[:transaction_id] || SecureRandom.uuid),
        attrs[:created_at] || Time.now,
        attrs[:amount_cents],
        attrs[:currency],
        attrs[:transaction_type],
        attrs[:status],
        normalize_uuid(attrs[:campaign_id]),
        attrs[:idempotency_key],
        attrs[:external_reference],
        attrs[:metadata]
      ],
      consistency: :quorum
    )
  end

  def find_by_owner(owner_id, owner_type, limit = 100)
    prepare!
    rows = CassandraClient.session.execute(
      @select_by_owner,
      arguments: [ owner_type.to_s, normalize_uuid(owner_id), limit ],
      consistency: :quorum
    )
    rows.map { |r| row_to_hash(r) }
  end

  # Update metadata for a specific transaction (replace metadata map)
  def update_metadata(owner_type, owner_id, transaction_id, new_metadata)
    prepare!
    update_cql = "UPDATE clareo.transactions_by_owner SET metadata = ? WHERE owner_type = ? AND owner_id = ? AND transaction_id = ?"
    CassandraClient.session.execute(
      update_cql,
      arguments: [ new_metadata, owner_type.to_s, normalize_uuid(owner_id), normalize_uuid(transaction_id) ],
      consistency: :quorum
    )
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end

  private

  def row_to_hash(row)
    {
      owner_type: row["owner_type"],
      owner_id: row["owner_id"]&.to_s,
      transaction_id: row["transaction_id"]&.to_s,
      created_at: row["created_at"],
      amount_cents: row["amount_cents"],
      currency: row["currency"],
      transaction_type: row["transaction_type"],
      status: row["status"],
      campaign_id: row["campaign_id"]&.to_s,
      idempotency_key: row["idempotency_key"],
      external_reference: row["external_reference"],
      metadata: row["metadata"]
    }
  end
end
