require "securerandom"

module CreditLinesRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.credit_lines
      (credit_id, organization_id, limit_cents, used_cents, available_cents, annual_rate, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    IF NOT EXISTS
  CQL

  SELECT_CQL = "SELECT * FROM clareo.credit_lines WHERE credit_id = ?"
  SELECT_BY_ORG_CQL = "SELECT * FROM clareo.credit_lines WHERE organization_id = ?"
  UPDATE_USED_CQL = <<~CQL
    UPDATE clareo.credit_lines
    SET used_cents = ?, available_cents = ?
    WHERE credit_id = ?
    IF used_cents = ?
  CQL

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @select = CassandraClient.session.prepare(SELECT_CQL)
    @select_by_org = CassandraClient.session.prepare(SELECT_BY_ORG_CQL)
    @update_used = CassandraClient.session.prepare(UPDATE_USED_CQL)
    @prepared = true
  end

  def create_if_not_exists(attrs)
    prepare!
    credit_id = normalize_uuid(attrs[:credit_id] || SecureRandom.uuid)
    now = Time.now
    result = CassandraClient.session.execute(
      @insert,
      arguments: [
        credit_id,
        normalize_uuid(attrs[:organization_id]),
        attrs[:limit_cents] || 0,
        attrs[:used_cents] || 0,
        attrs[:available_cents] || (attrs[:limit_cents] || 0),
        attrs[:annual_rate],
        attrs[:status] || "active",
        now
      ],
      consistency: :quorum
    )

    applied = result.first && result.first["[applied]"] == true
    [applied, find(credit_id)]
  end

  def find(credit_id)
    prepare!
    row = CassandraClient.session.execute(
      @select,
      arguments: [ normalize_uuid(credit_id) ],
      consistency: :quorum
    ).first
    row && row_to_hash(row)
  end

  def find_by_organization(organization_id)
    prepare!
    rows = CassandraClient.session.execute(
      @select_by_org,
      arguments: [ normalize_uuid(organization_id) ],
      consistency: :quorum
    )
    rows.map { |r| row_to_hash(r) }
  end

  # List all credit lines (used by background processors)
  def all
    prepare!
    rows = CassandraClient.session.execute("SELECT * FROM clareo.credit_lines", consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def update_used_if_expected(credit_id:, expected_used:, new_used:, new_available:)
    prepare!
    result = CassandraClient.session.execute(
      @update_used,
      arguments: [ new_used, new_available, normalize_uuid(credit_id), expected_used ],
      consistency: :quorum
    )
    applied = result.first && result.first["[applied]"] == true
    [applied, find(credit_id)]
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end

  private

  def row_to_hash(row)
    {
      credit_id: row["credit_id"].to_s,
      organization_id: row["organization_id"].to_s,
      limit_cents: row["limit_cents"],
      used_cents: row["used_cents"],
      available_cents: row["available_cents"],
      annual_rate: row["annual_rate"],
      status: row["status"],
      created_at: row["created_at"]
    }
  end
end
