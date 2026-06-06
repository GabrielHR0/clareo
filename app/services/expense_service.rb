class ExpenseService
  ValidationError = Class.new(StandardError)

  def self.create(attrs)
    attrs[:entry_id] ||= SecureRandom.uuid
    raise ValidationError, "organization_id is required" unless attrs[:organization_id]
    raise ValidationError, "campaign_id is required" unless attrs[:campaign_id]
    raise ValidationError, "description is required" unless attrs[:description] && !attrs[:description].empty?
    raise ValidationError, "amount_cents is required" unless attrs[:amount_cents]
    raise ValidationError, "amount_cents must be positive" unless attrs[:amount_cents].to_i > 0

    org = OrganizationsRepository.find(attrs[:organization_id])
    raise ValidationError, "Organization not found" unless org

    ExpenseEntriesRepository.create(attrs)
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

    expenses = ExpenseEntriesRepository.list(org_id, campaign_id)
    total_spent = expenses.sum { |e| e[:amount_cents] || 0 }
    raised = campaign[:raised_cents] || 0

    expenses_with_attachments = expenses.map do |expense|
      attachments = ExpenseAttachmentsRepository.list(org_id, campaign_id, expense[:entry_id])
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
        status: campaign[:status]
      },
      summary: {
        total_raised: raised,
        total_spent: total_spent,
        balance: raised - total_spent,
        expense_count: expenses.size
      },
      expenses: expenses_with_attachments
    }
  end
end
