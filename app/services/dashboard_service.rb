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
    org_wide_expenses = ExpenseEntriesRepository.list_by_org(org_id)

    campaign_details = campaigns.map do |c|
      expenses = ExpenseEntriesRepository.list(org_id, c[:campaign_id])
      spent = expenses.sum { |e| e[:amount_cents] || 0 }
      raised = c[:raised_cents] || 0
      held = c[:held_cents] || 0
      goal = c[:goal_cents] || 0
      progress = goal > 0 ? (raised.to_f / goal * 100).round(1) : 0.0

      {
        campaign_id: c[:campaign_id].to_s,
        name: c[:name],
        status: c[:status],
        raised_cents: raised,
        held_cents: held,
        spent_cents: spent,
        balance_cents: raised - spent,
        available_balance_cents: held - spent,
        goal_cents: goal,
        expense_count: expenses.size,
        progress_pct: progress
      }
    end

    total_raised = campaigns.sum { |c| c[:raised_cents] || 0 }
    total_spent = campaign_details.sum { |c| c[:spent_cents] } + org_wide_expenses.sum { |e| e[:amount_cents] || 0 }
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
        credit_line_available_cents: credit_lines.sum { |cl| cl[:available_cents] || 0 },
        org_wide_expense_count: org_wide_expenses.size,
        org_wide_spent_cents: org_wide_expenses.sum { |e| e[:amount_cents] || 0 }
      },
      campaigns: campaign_details,
      org_wide_expenses: org_wide_expenses.map { |e| expense_to_hash(e, org_id) },
      recent_transactions: recent_txns.map { |t| transaction_to_hash(t) }
    }
  end

  def expense_to_hash(e, org_id)
    {
      entry_id: e[:entry_id].to_s,
      description: e[:description],
      amount_cents: e[:amount_cents],
      category: e[:category],
      type: e[:type],
      expense_date: e[:expense_date]&.iso8601,
      status: e[:status],
      campaign_id: e[:campaign_id].to_s
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
