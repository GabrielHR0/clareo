class DirectDonationService
  def self.call(organization_id:, contributor_attrs:, amount_cents:, currency: "BRL", payment: {}, idempotency_key: nil, metadata: {})
    new(
      organization_id: organization_id,
      contributor_attrs: contributor_attrs,
      amount_cents: amount_cents,
      currency: currency,
      payment: payment,
      idempotency_key: idempotency_key,
      metadata: metadata
    ).process
  end

  def initialize(organization_id:, contributor_attrs:, amount_cents:, currency:, payment:, idempotency_key:, metadata:)
    @organization_id = organization_id
    @contributor_attrs = contributor_attrs || {}
    @amount_cents = amount_cents.to_i
    @currency = currency || "BRL"
    @payment = payment || {}
    @idempotency_key = idempotency_key
    @metadata = stringify_keys(metadata || {})
  end

  def process
    org = OrganizationsRepository.find(@organization_id)
    raise "Organization not found" unless org

    contributor = find_or_create_contributor
    create_membership(contributor[:contributor_id], org[:organization_id])

    tx_key = "donation_#{@idempotency_key || SecureRandom.uuid}"
    meta = (@metadata || {}).merge("contributor_id" => contributor[:contributor_id].to_s)
    result = ProcessTransactionService.call(
      owner_type: "organization",
      owner_id: org[:organization_id],
      amount_cents: @amount_cents,
      currency: @currency,
      transaction_type: "credit",
      idempotency_key: tx_key,
      metadata: meta
    )

    {
      status: result[:status],
      transaction_id: result[:transaction_id],
      contributor: contributor,
      organization_id: @organization_id,
      organization_name: org[:name]
    }
  end

  private

  def stringify_keys(hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
  end

  def find_or_create_contributor
    email = @contributor_attrs[:email]
    return CreateContributorService.call(@contributor_attrs)[:contributor] unless email

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
