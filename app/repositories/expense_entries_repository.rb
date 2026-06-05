module ExpenseEntriesRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.expense_entries (organization_id, campaign_id, entry_id, description, amount_cents, category, expense_date, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.expense_entries WHERE organization_id = ? AND campaign_id = ? AND entry_id = ?"
  LIST_CQL = "SELECT * FROM clareo.expense_entries WHERE organization_id = ? AND campaign_id = ?"
  DELETE_CQL = "DELETE FROM clareo.expense_entries WHERE organization_id = ? AND campaign_id = ? AND entry_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:entry_id])
    org_id = normalize_uuid(attrs[:organization_id])
    campaign_id = normalize_uuid(attrs[:campaign_id])
    now = Time.now
    expense_date = attrs[:expense_date]
    expense_date = Date.parse(expense_date) if expense_date.is_a?(String)

    CassandraClient.session.execute(@insert, arguments: [
      org_id, campaign_id, id,
      attrs[:description],
      attrs[:amount_cents].to_i,
      attrs[:category],
      expense_date,
      attrs[:status] || "active",
      now, now
    ], consistency: :quorum)

    { entry_id: id.to_s, organization_id: org_id.to_s, campaign_id: campaign_id.to_s }
  end

  def find(org_id, campaign_id, entry_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id), normalize_uuid(campaign_id), normalize_uuid(entry_id)
    ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def list(org_id, campaign_id)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id), normalize_uuid(campaign_id)
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def delete(org_id, campaign_id, entry_id)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [
      normalize_uuid(org_id), normalize_uuid(campaign_id), normalize_uuid(entry_id)
    ], consistency: :quorum)
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      entry_id: row["entry_id"].to_s,
      organization_id: row["organization_id"].to_s,
      campaign_id: row["campaign_id"].to_s,
      description: row["description"],
      amount_cents: row["amount_cents"],
      category: row["category"],
      expense_date: row["expense_date"],
      status: row["status"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
