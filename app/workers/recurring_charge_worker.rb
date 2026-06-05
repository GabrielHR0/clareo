class RecurringChargeWorker
  include Sidekiq::Worker

  def perform(limit = 100)
    orgs = OrganizationsRepository.all(1000)
    return if orgs.empty?

    service = SubscriptionChargeService.new

    orgs.each do |org|
      org_id = org[:organization_id]
      next unless org_id

      due = RecurringDonationsRepository.find_due(org_id, Date.today, limit)

      due.each do |recurring|
        result = service.process(recurring)
        if result[:status] == :ok
          interval = recurring[:interval_days] || 30
          new_date = (recurring[:next_charge_date] || Date.today) + interval
          RecurringDonationsRepository.advance_next_charge(
            recurring[:organization_id],
            recurring[:contributor_id],
            recurring[:recurring_id],
            new_date
          )
        end
      end
    end
  end
end
