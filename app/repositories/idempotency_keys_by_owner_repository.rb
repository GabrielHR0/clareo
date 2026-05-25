require "securerandom"

module IdempotencyKeysByOwnerRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.idempotency_keys_by_owner
      (owner_type, owner_id, idempotency_key, transaction_id, request_hash, created_at, expires_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    IF NOT EXISTS
  CQL

  SELECT_CQL = "SELECT * FROM clareo.idempotency_keys_by_owner WHERE owner_type = ? AND owner_id = ? AND idempotency_key = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @select = CassandraClient.session.prepare(SELECT_CQL)
    @prepared = true
  end

  def create_if_not_exists(attrs)
    prepare!
    now = Time.now
    result = with_retries do
      CassandraClient.session.execute(
        @insert,
        arguments: [
          attrs[:owner_type].to_s,
          normalize_uuid(attrs[:owner_id]),
          attrs[:idempotency_key],
          normalize_uuid(attrs[:transaction_id] || SecureRandom.uuid),
          attrs[:request_hash],
          now,
          attrs[:expires_at]
        ],
        consistency: :quorum
      )
    end

    applied = result.first && result.first["[applied]"] == true
    [applied, find(attrs[:owner_id], attrs[:owner_type], attrs[:idempotency_key])]
  end

  def with_retries(max_attempts: 3, base_sleep: 0.01)
    attempts = 0
    begin
      return yield
    rescue Cassandra::Errors::WriteTimeoutError, Cassandra::Errors::ReadTimeoutError => e
      attempts += 1
      raise if attempts >= max_attempts
      sleep(base_sleep * (2 ** (attempts - 1)))
      retry
    end
  end

  def find(owner_id, owner_type, idempotency_key)
    prepare!
    row = CassandraClient.session.execute(
      @select,
      arguments: [ owner_type.to_s, normalize_uuid(owner_id), idempotency_key ],
      consistency: :quorum
    ).first
    row && row_to_hash(row)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end

  private

  def row_to_hash(row)
    {
      owner_type: row["owner_type"],
      owner_id: row["owner_id"],
      idempotency_key: row["idempotency_key"],
      transaction_id: row["transaction_id"],
      request_hash: row["request_hash"],
      created_at: row["created_at"],
      expires_at: row["expires_at"]
    }
  end
end
