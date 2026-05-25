require "securerandom"

module LedgerEntriesByOwnerRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.ledger_entries_by_owner
      (owner_type, owner_id, entry_id, created_at, transaction_id, entry_type, account, amount_cents, balance_after_cents, description)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  SELECT_BY_OWNER_CQL = <<~CQL
    SELECT * FROM clareo.ledger_entries_by_owner
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
        normalize_uuid(attrs[:entry_id] || SecureRandom.uuid),
        attrs[:created_at] || Time.now,
        normalize_uuid(attrs[:transaction_id]),
        attrs[:entry_type],
        attrs[:account],
        attrs[:amount_cents],
        attrs[:balance_after_cents],
        attrs[:description]
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

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end

  private

  def row_to_hash(row)
    {
      owner_type: row["owner_type"],
      owner_id: row["owner_id"],
      entry_id: row["entry_id"],
      created_at: row["created_at"],
      transaction_id: row["transaction_id"],
      entry_type: row["entry_type"],
      account: row["account"],
      amount_cents: row["amount_cents"],
      balance_after_cents: row["balance_after_cents"],
      description: row["description"]
    }
  end
end
