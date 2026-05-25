require "securerandom"

module TransactionsByCampaignRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.transactions_by_campaign
      (campaign_id, created_at, transaction_id, owner_type, owner_id, amount_cents, currency, transaction_type, status, idempotency_key, external_reference, metadata)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  SELECT_BY_CAMPAIGN_CQL = <<~CQL
    SELECT * FROM clareo.transactions_by_campaign
    WHERE campaign_id = ?
    ORDER BY created_at DESC
    LIMIT ?
  CQL

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @select_by_campaign = CassandraClient.session.prepare(SELECT_BY_CAMPAIGN_CQL)
    @prepared = true
  end

  def insert(attrs)
    prepare!
    CassandraClient.session.execute(
      @insert,
      arguments: [
        normalize_uuid(attrs[:campaign_id]),
        attrs[:created_at] || Time.now,
        normalize_uuid(attrs[:transaction_id] || SecureRandom.uuid),
        attrs[:owner_type].to_s,
        normalize_uuid(attrs[:owner_id]),
        attrs[:amount_cents],
        attrs[:currency],
        attrs[:transaction_type],
        attrs[:status],
        attrs[:idempotency_key],
        attrs[:external_reference],
        attrs[:metadata]
      ],
      consistency: :quorum
    )
  end

  def find_by_campaign(campaign_id, limit = 100)
    prepare!
    rows = CassandraClient.session.execute(
      @select_by_campaign,
      arguments: [ normalize_uuid(campaign_id), limit ],
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
      campaign_id: row['campaign_id'],
      transaction_id: row['transaction_id'],
      owner_type: row['owner_type'],
      owner_id: row['owner_id'],
      created_at: row['created_at'],
      amount_cents: row['amount_cents'],
      currency: row['currency'],
      transaction_type: row['transaction_type'],
      status: row['status'],
      idempotency_key: row['idempotency_key'],
      external_reference: row['external_reference'],
      metadata: row['metadata']
    }
  end
end
