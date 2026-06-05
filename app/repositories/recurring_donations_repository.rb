require "securerandom"

module RecurringDonationsRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.recurring_donations
      (organization_id, contributor_id, recurring_id, amount_cents, currency, payment_method, card_reference, interval_days, next_charge_date, campaign_id, status, start_date, end_date, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.recurring_donations WHERE organization_id = ? AND contributor_id = ? AND recurring_id = ?"
  LIST_BY_CONTRIBUTOR_CQL = "SELECT * FROM clareo.recurring_donations WHERE contributor_id = ? ALLOW FILTERING"
  SELECT_DUE_CQL = "SELECT * FROM clareo.recurring_donations WHERE organization_id = ? AND next_charge_date <= ? LIMIT ? ALLOW FILTERING"
  UPDATE_NEXT_CQL = "UPDATE clareo.recurring_donations SET next_charge_date = ? WHERE organization_id = ? AND contributor_id = ? AND recurring_id = ?"
  CANCEL_CQL = "UPDATE clareo.recurring_donations SET status = ? WHERE organization_id = ? AND contributor_id = ? AND recurring_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @list_by_contributor = CassandraClient.session.prepare(LIST_BY_CONTRIBUTOR_CQL)
    @select_due = CassandraClient.session.prepare(SELECT_DUE_CQL)
    @update_next = CassandraClient.session.prepare(UPDATE_NEXT_CQL)
    @cancel = CassandraClient.session.prepare(CANCEL_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:recurring_id])
    org_id = normalize_uuid(attrs[:organization_id])
    contrib_id = normalize_uuid(attrs[:contributor_id])
    now = Time.now
    status = attrs[:status] || "active"
    next_charge = attrs[:next_charge_date] || (Date.today + 1)
    interval = attrs[:interval_days] || 30

    CassandraClient.session.execute(@insert, arguments: [
      org_id,
      contrib_id,
      id,
      attrs[:amount_cents].to_i,
      attrs[:currency] || "BRL",
      attrs[:payment_method],
      attrs[:card_reference],
      interval,
      next_charge,
      normalize_uuid(attrs[:campaign_id]),
      status,
      attrs[:start_date] || now,
      attrs[:end_date],
      now
    ], consistency: :quorum)

    { recurring_id: id.to_s, organization_id: org_id.to_s, contributor_id: contrib_id.to_s }
  end

  def find(org_id, contributor_id, recurring_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id),
      normalize_uuid(contributor_id),
      normalize_uuid(recurring_id)
    ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def list_by_contributor(contributor_id)
    prepare!
    rows = CassandraClient.session.execute(@list_by_contributor, arguments: [
      normalize_uuid(contributor_id)
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def find_due(organization_id, as_of = Date.today, limit = 100)
    prepare!
    rows = CassandraClient.session.execute(@select_due, arguments: [
      normalize_uuid(organization_id), as_of, limit
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def advance_next_charge(org_id, contributor_id, recurring_id, new_date)
    prepare!
    CassandraClient.session.execute(@update_next, arguments: [
      new_date,
      normalize_uuid(org_id),
      normalize_uuid(contributor_id),
      normalize_uuid(recurring_id)
    ], consistency: :quorum)
  end

  def cancel(org_id, contributor_id, recurring_id)
    prepare!
    CassandraClient.session.execute(@cancel, arguments: [
      "cancelled",
      normalize_uuid(org_id),
      normalize_uuid(contributor_id),
      normalize_uuid(recurring_id)
    ], consistency: :quorum)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    return if value.nil?
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"]&.to_s,
      contributor_id: row["contributor_id"]&.to_s,
      recurring_id: row["recurring_id"]&.to_s,
      amount_cents: row["amount_cents"],
      currency: row["currency"],
      payment_method: row["payment_method"],
      card_reference: row["card_reference"],
      interval_days: row["interval_days"],
      next_charge_date: row["next_charge_date"],
      campaign_id: row["campaign_id"]&.to_s,
      status: row["status"],
      start_date: row["start_date"],
      end_date: row["end_date"],
      created_at: row["created_at"]
    }
  end
end
