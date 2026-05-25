require "securerandom"

module WalletsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.wallets 
      (owner_id, owner_type, balance_cents, available_cents, locked_cents, version, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    IF NOT EXISTS
  CQL

  GET_CQL = "SELECT * FROM clareo.wallets WHERE owner_id = ? AND owner_type = ?"
  UPDATE_CQL = <<~CQL
    UPDATE clareo.wallets
    SET balance_cents = ?, available_cents = ?, locked_cents = ?, version = ?, updated_at = ?
    WHERE owner_type = ? AND owner_id = ?
    IF version = ?
  CQL

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @update = CassandraClient.session.prepare(UPDATE_CQL)
    @prepared = true
  end

  def create_if_not_exists(attrs)
    prepare!
    owner_id = normalize_uuid(attrs[:owner_id])
    now = Time.now

    result = CassandraClient.session.execute(
      @insert,
      arguments: [
        owner_id,
        attrs[:owner_type],
        attrs[:balance_cents],
        attrs[:available_cents],
        attrs[:locked_cents],
        attrs[:version],
        now,
        now
      ],
      consistency: :quorum
    )

    applied = result.first && result.first["[applied]"] == true
    wallet = find(owner_id, attrs[:owner_type])
    [applied, wallet]
  end

  def update_balances_if_version(owner_id:, owner_type:, balance_cents:, available_cents:, locked_cents:, expected_version:)
    prepare!
    raise ArgumentError, "expected_version is required" if expected_version.nil?

    owner_id = normalize_uuid(owner_id)
    new_version = expected_version.to_i + 1
    now = Time.now

    result = with_retries do
      CassandraClient.session.execute(
        @update,
        arguments: [
          balance_cents,
          available_cents,
          locked_cents,
          new_version,
          now,
          owner_type.to_s,
          owner_id,
          expected_version
        ],
        consistency: :quorum
      )
    end

    applied = result.first && result.first["[applied]"] == true
    wallet = find(owner_id, owner_type)
    [applied, wallet]
  end

  def find(owner_id, owner_type)
    prepare!
    row = CassandraClient.session.execute(
     @get,
     arguments: [ normalize_uuid(owner_id), owner_type.to_s ],
      consistency: :quorum
    ).first
    
    row && row_to_hash(row)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
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

  private

  def row_to_hash(row)
    {
      owner_id: row["owner_id"],
      owner_type: row["owner_type"],
      balance_cents: row["balance_cents"],
      available_cents: row["available_cents"],
      locked_cents: row["locked_cents"],
      version: row["version"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end