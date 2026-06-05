class CheckoutService
  def self.process(attrs)
    new(attrs).process
  end

  def initialize(attrs)
    @campaign_id = attrs[:campaign_id]
    @contributor_attrs = attrs[:contributor] || {}
    @amount_cents = attrs[:amount_cents].to_i
    @currency = attrs[:currency] || "BRL"
    @payment = attrs[:payment] || {}
    @idempotency_key = attrs[:idempotency_key]
    @metadata = stringify_keys(attrs[:metadata] || {})
  end

  def stringify_keys(hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
  end

  def process
    campaign = CampaignsByIdRepository.find(@campaign_id)
    raise "Campaign not found" unless campaign

    contributor = find_or_create_contributor
    create_membership(contributor[:contributor_id], campaign[:organization_id])

    tx_key = "checkout_#{@idempotency_key}"
    meta = (@metadata || {}).merge("contributor_id" => contributor[:contributor_id].to_s)
    result = ProcessTransactionService.call(
      owner_type: "organization",
      owner_id: campaign[:organization_id],
      amount_cents: @amount_cents,
      currency: @currency,
      transaction_type: "credit",
      idempotency_key: tx_key,
      campaign_id: @campaign_id,
      metadata: meta
    )

    {
      status: result[:status],
      transaction_id: result[:transaction_id],
      contributor: contributor,
      campaign_id: @campaign_id
    }
  end

  private

  def find_or_create_contributor
    email = @contributor_attrs[:email]
    return CreateContributorService.call(@contributor_attrs)[:contributor] unless email

    # try to find by email — scanning with ALLOW FILTERING is acceptable for MVP (small data)
    existing = ContributorsRepository.find_by_email(email)
    return existing if existing

    CreateContributorService.call(@contributor_attrs)[:contributor]
  end

  def create_membership(contributor_id, organization_id)
    existing = MembershipsRepository.for_organization(organization_id)
    return if existing.any? { |m| m[:contributor_id].to_s == contributor_id.to_s }

    MembershipsRepository.create(
      membership_id: SecureRandom.uuid,
      organization_id: organization_id,
      contributor_id: contributor_id,
      status: "active"
    )
  end
end
