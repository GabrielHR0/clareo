require_relative "../../lib/event_bus"

class CampaignService
  def self.create(attrs)
    attrs[:campaign_id] ||= SecureRandom.uuid
    attrs[:status] ||= "draft"
    attrs[:raised_cents] ||= 0

    if attrs[:goal_cents].to_i < 0
      raise ArgumentError, "goal_cents must be non-negative"
    end

    id = CampaignsRepository.create(attrs)
    { campaign_id: id[:campaign_id].to_s, organization_id: id[:organization_id].to_s }
  end

  def self.redeem(org_id, campaign_id, amount_cents:, description: nil)
    campaign = CampaignsRepository.find(org_id, campaign_id)
    raise ArgumentError, "Campaign not found" unless campaign

    amount = amount_cents.to_i
    raise ArgumentError, "amount_cents must be positive" if amount <= 0

    current_held = campaign[:held_cents] || 0
    raise ArgumentError, "Insufficient held funds" if current_held < amount

    tx_key = "redemption_#{org_id}_#{campaign_id}_#{SecureRandom.uuid}"
    meta = { "campaign_id" => campaign_id.to_s, "redemption" => "true", "description" => description || "Resgate" }
    result = ProcessTransactionService.call(
      owner_type: "organization",
      owner_id: org_id,
      amount_cents: amount,
      currency: "BRL",
      transaction_type: "credit",
      idempotency_key: tx_key,
      metadata: meta
    )

    raise "Redemption transaction failed: #{result[:status]}" unless result[:status] == :ok

    new_held = current_held - amount
    attrs = campaign.merge(held_cents: new_held)
    CampaignsRepository.update(attrs)

    tags = attrs[:tags] || []
    tags.each do |tag|
      CampaignsByTagRepository.insert(
        tag: tag,
        campaign_id: campaign_id,
        organization_id: org_id,
        name: attrs[:name],
        cover_image: attrs[:cover_image],
        cover_color: attrs[:cover_color],
        goal_cents: attrs[:goal_cents],
        raised_cents: attrs[:raised_cents],
        held_cents: new_held,
        status: attrs[:status]
      )
    end

    expense_desc = description || "Resgate de #{format_cents(amount)}"
    ExpenseEntriesRepository.create(
      organization_id: org_id,
      campaign_id: campaign_id,
      description: expense_desc,
      amount_cents: amount,
      type: "redemption",
      status: "completed",
      expense_date: Date.today
    )

    result_data = CampaignsRepository.find(org_id, campaign_id)

    EventBus.publish("donation.redeemed", {
      organization_id: org_id,
      campaign_id: campaign_id,
      amount_cents: amount,
      description: expense_desc,
      timestamp: Time.now.iso8601
    })

    result_data
  end

  def self.format_cents(cents)
    "R$ #{cents.to_i / 100},#{(cents.to_i % 100).to_s.rjust(2, '0')}"
  end

  def self.update(org_id, campaign_id, attrs)
    existing = CampaignsRepository.find(org_id, campaign_id)
    raise ArgumentError, "Campaign not found" unless existing

    attrs = attrs.to_h.symbolize_keys if attrs.respond_to?(:to_h)
    sym_attrs = attrs.transform_keys(&:to_sym)
    old_tags = (existing[:tags] || []).to_set
    new_tags = (sym_attrs[:tags] || old_tags).to_set
    removed = old_tags - new_tags
    removed.each { |tag| CampaignsByTagRepository.delete(tag: tag, campaign_id: campaign_id) }

    merged = existing.merge(sym_attrs)
    merged[:campaign_id] = campaign_id
    merged[:organization_id] = org_id

    CampaignsRepository.update(merged)
    CampaignsRepository.find(org_id, campaign_id)
  end
end
