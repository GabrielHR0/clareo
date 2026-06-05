module DashboardService
  module_function

  def call(org_id)
    org = OrganizationsRepository.find(org_id)
    return nil unless org

    campaigns = CampaignsRepository.list(org_id)
    members = MembershipsRepository.for_organization(org_id)
    wallet = WalletsRepository.find(org_id, "organization")
    credit_lines = CreditLinesRepository.find_by_organization(org_id)
    recent_txns = TransactionsByOwnerRepository.find_by_owner(org_id, "organization", 20)

    campaign_details = campaigns.map do |c|
      expenses = ExpenseEntriesRepository.list(org_id, c[:campaign_id])
      spent = expenses.sum { |e| e[:amount_cents] || 0 }
      raised = c[:raised_cents] || 0
      goal = c[:goal_cents] || 0
      progress = goal > 0 ? (raised.to_f / goal * 100).round(1) : 0.0

      {
        campaign_id: c[:campaign_id].to_s,
        name: c[:name],
        status: c[:status],
        raised_cents: raised,
        spent_cents: spent,
        balance_cents: raised - spent,
        goal_cents: goal,
        progress_pct: progress
      }
    end

    total_raised = campaigns.sum { |c| c[:raised_cents] || 0 }
    total_spent = campaign_details.sum { |c| c[:spent_cents] }
    active_count = campaigns.count { |c| c[:status] == "active" }

    {
      organization_id: org[:organization_id].to_s,
      name: org[:name],
      metrics: {
        total_raised_cents: total_raised,
        total_spent_cents: total_spent,
        balance_cents: total_raised - total_spent,
        wallet_available_cents: wallet ? wallet[:available_cents] : 0,
        active_campaigns: active_count,
        total_campaigns: campaigns.size,
        member_count: members.size,
        credit_line_available_cents: credit_lines.sum { |cl| cl[:available_cents] || 0 }
      },
      campaigns: campaign_details,
      recent_transactions: recent_txns.map { |t| transaction_to_hash(t) }
    }
  end

  def transaction_to_hash(t)
    {
      transaction_id: t[:transaction_id].to_s,
      amount_cents: t[:amount_cents],
      transaction_type: t[:transaction_type],
      status: t[:status],
      campaign_id: t[:campaign_id]&.to_s,
      created_at: t[:created_at]&.iso8601
    }
  end
end
