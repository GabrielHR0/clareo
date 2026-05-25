class RecurringDonationsRepository
  SELECT_DUE = "SELECT * FROM clareo.recurring_donations WHERE organization_id = ? AND next_charge_date <= ? LIMIT ?"
  UPDATE_NEXT = "UPDATE clareo.recurring_donations SET next_charge_date = ? WHERE organization_id = ? AND contributor_id = ? AND recurring_id = ?"

  def initialize(session = CassandraCluster.instance)
    @session = session
  end

  # Find due recurring donations for an organization up to today
  def find_due(organization_id, as_of = Date.today, limit = 100)
    rows = @session.execute(SELECT_DUE, arguments: [organization_id.to_s, as_of, limit])
    rows.map do |row|
      {
        recurring_id: row['recurring_id'],
        contributor_id: row['contributor_id'],
        organization_id: row['organization_id'],
        amount_cents: row['amount_cents'],
        currency: row['currency'],
        payment_method: row['payment_method'],
        card_reference: row['card_reference'],
        next_charge_date: row['next_charge_date']
      }
    end
  end

  def advance_next_charge(organization_id, contributor_id, recurring_id, new_date)
    @session.execute(UPDATE_NEXT, arguments: [new_date, organization_id.to_s, contributor_id.to_s, recurring_id.to_s])
  end
end
