require_relative "../../lib/event_bus"

class ExpenseService
  ValidationError = Class.new(StandardError)

  SENTINEL_CAMPAIGN = "00000000-0000-0000-0000-000000000000"

  def self.create(attrs)
    attrs[:entry_id] ||= SecureRandom.uuid
    attrs[:type] ||= "expense"
    raise ValidationError, "organization_id is required" unless attrs[:organization_id]
    raise ValidationError, "description is required" unless attrs[:description] && !attrs[:description].empty?
    raise ValidationError, "amount_cents is required for expenses" if attrs[:type] == "expense" && !attrs[:amount_cents]
    raise ValidationError, "amount_cents must be positive" if attrs[:type] == "expense" && attrs[:amount_cents].to_i <= 0

    attrs[:campaign_id] = SENTINEL_CAMPAIGN if attrs[:campaign_id].blank?

    org = OrganizationsRepository.find(attrs[:organization_id])
    raise ValidationError, "Organization not found" unless org

    ExpenseEntriesRepository.create(attrs)

    EventBus.publish("expense.created", {
      organization_id: attrs[:organization_id].to_s,
      campaign_id: attrs[:campaign_id].to_s,
      entry_id: attrs[:entry_id].to_s,
      description: attrs[:description],
      amount_cents: attrs[:amount_cents].to_i,
      type: attrs[:type] || "expense",
      timestamp: Time.now.iso8601
    })
  end

  def self.update(org_id, campaign_id, entry_id, attrs)
    existing = ExpenseEntriesRepository.find(org_id, campaign_id, entry_id)
    raise ValidationError, "Expense entry not found" unless existing
    raise ValidationError, "Cannot modify cancelled entry" if existing[:status] == "cancelled"

    merged = existing.merge(attrs)
    merged[:entry_id] = entry_id
    merged[:organization_id] = org_id
    merged[:campaign_id] = campaign_id

    ExpenseEntriesRepository.create(merged)

    ExpenseEntriesRepository.find(org_id, campaign_id, entry_id)
  end

  def self.delete(org_id, campaign_id, entry_id)
    attachments = ExpenseAttachmentsRepository.list(org_id, campaign_id, entry_id)
    attachments.each do |att|
      ExpenseAttachmentsRepository.delete(org_id, campaign_id, entry_id, att[:attachment_id])
    end
    ExpenseEntriesRepository.delete(org_id, campaign_id, entry_id)
  end

  def self.accountability(org_id, campaign_id)
    org = OrganizationsRepository.find(org_id)
    return nil unless org

    campaign = CampaignsRepository.find(org_id, campaign_id)
    return nil unless campaign

    campaign_expenses = ExpenseEntriesRepository.list(org_id, campaign_id)
    org_expenses = ExpenseEntriesRepository.list_by_org(org_id)
    all_expenses = campaign_expenses + org_expenses
    total_spent = all_expenses.select { |e| e[:type] != "redemption" }.sum { |e| e[:amount_cents] || 0 }
    total_redemption = all_expenses.select { |e| e[:type] == "redemption" }.sum { |e| e[:amount_cents] || 0 }
    raised = campaign[:raised_cents] || 0

    expenses_with_attachments = all_expenses.map do |expense|
      e_campaign_id = expense[:campaign_id]
      attachments = ExpenseAttachmentsRepository.list(org_id, e_campaign_id, expense[:entry_id])
      expense.merge(attachments: attachments)
    end

    {
      organization: { id: org[:organization_id].to_s, name: org[:name] },
      campaign: {
        id: campaign[:campaign_id].to_s,
        name: campaign[:name],
        description: campaign[:description],
        goal_cents: campaign[:goal_cents],
        raised_cents: raised,
        held_cents: campaign[:held_cents] || 0,
        status: campaign[:status]
      },
      summary: {
        total_raised: raised,
        total_held: campaign[:held_cents] || 0,
        total_spent: total_spent,
        total_redemption: total_redemption,
        balance: raised - total_spent - total_redemption,
        expense_count: all_expenses.size
      },
      expenses: expenses_with_attachments
    }
  end
end
