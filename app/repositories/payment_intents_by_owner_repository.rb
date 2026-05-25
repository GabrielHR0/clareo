require "securerandom"

module PaymentIntentsByOwnerRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.payment_intents_by_owner
      (owner_type, owner_id, payment_intent_id, amount_cents, campaign_id, status, provider, provider_reference, authorized_at, captured_at, failed_reason, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  SELECT_CQL = "SELECT * FROM clareo.payment_intents_by_owner WHERE owner_type = ? AND owner_id = ? AND payment_intent_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @select = CassandraClient.session.prepare(SELECT_CQL)
    @prepared = true
  end

  def insert(attrs)
    prepare!
    CassandraClient.session.execute(
      @insert,
      arguments: [
        attrs[:owner_type].to_s,
        normalize_uuid(attrs[:owner_id]),
        normalize_uuid(attrs[:payment_intent_id] || SecureRandom.uuid),
        attrs[:amount_cents],
        normalize_uuid(attrs[:campaign_id]),
        attrs[:status],
        attrs[:provider],
        attrs[:provider_reference],
        attrs[:authorized_at],
        attrs[:captured_at],
        attrs[:failed_reason],
        attrs[:created_at] || Time.now
      ],
      consistency: :quorum
    )
  end

  def find(owner_id, owner_type, payment_intent_id)
    prepare!
    row = CassandraClient.session.execute(
      @select,
      arguments: [ owner_type.to_s, normalize_uuid(owner_id), normalize_uuid(payment_intent_id) ],
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
      payment_intent_id: row["payment_intent_id"],
      amount_cents: row["amount_cents"],
      campaign_id: row["campaign_id"],
      status: row["status"],
      provider: row["provider"],
      provider_reference: row["provider_reference"],
      authorized_at: row["authorized_at"],
      captured_at: row["captured_at"],
      failed_reason: row["failed_reason"],
      created_at: row["created_at"]
    }
  end
end
