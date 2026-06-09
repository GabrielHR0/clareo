require "securerandom"

module CreditBillsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.credit_bills (organization_id, bill_id, credit_id, due_date, amount_cents, paid_cents, status, created_at, paid_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  LIST_CQL = "SELECT * FROM clareo.credit_bills WHERE organization_id = ? ORDER BY bill_id DESC LIMIT ?"
  FIND_CQL = "SELECT * FROM clareo.credit_bills WHERE organization_id = ? AND bill_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @list = CassandraClient.session.prepare(LIST_CQL)
    @find = CassandraClient.session.prepare(FIND_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:bill_id])
    CassandraClient.session.execute(
      @insert,
      arguments: [
        normalize_uuid(attrs[:organization_id]),
        id,
        normalize_uuid(attrs[:credit_id]),
        attrs[:due_date],
        attrs[:amount_cents].to_i,
        attrs[:paid_cents].to_i,
        attrs[:status] || "pending",
        attrs[:created_at] || Time.now,
        attrs[:paid_at]
      ],
      consistency: :quorum
    )
    id
  end

  def list(organization_id, limit = 50)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [normalize_uuid(organization_id), limit], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def find(organization_id, bill_id)
    prepare!
    row = CassandraClient.session.execute(@find, arguments: [normalize_uuid(organization_id), normalize_uuid(bill_id)], consistency: :quorum).first
    row && row_to_hash(row)
  end

  private

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    return nil unless value
    Cassandra::Uuid.new(value)
  rescue ArgumentError
    nil
  end

  def row_to_hash(row)
    {
      organization_id: row["organization_id"]&.to_s,
      bill_id: row["bill_id"]&.to_s,
      credit_id: row["credit_id"]&.to_s,
      due_date: row["due_date"],
      amount_cents: row["amount_cents"],
      paid_cents: row["paid_cents"],
      status: row["status"],
      created_at: row["created_at"],
      paid_at: row["paid_at"]
    }
  end
end
