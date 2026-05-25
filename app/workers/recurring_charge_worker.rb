class RecurringChargeWorker
  include Sidekiq::Worker

  def perform(limit = 100)
    repos = RecurringDonationsRepository.new
    due = repos.find_due(all_organizations_first, Date.today, limit)
    service = SubscriptionChargeService.new

    due.each do |recurring|
      res = service.process(recurring)
      if res[:status] == :ok
        # advance next_charge_date by interval; for now add 30 days
        new_date = (recurring[:next_charge_date] || Date.today) + 30
        repos.advance_next_charge(recurring[:organization_id], recurring[:contributor_id], recurring[:recurring_id], new_date)
      end
    end
  end

  private

  # Placeholder: returns an organization id or list; in multi-tenant set proper scope
  def all_organizations_first
    # For now use a broad default; ideally iterate over organizations
    'default'
  end
end
