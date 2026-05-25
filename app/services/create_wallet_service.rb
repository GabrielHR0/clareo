class CreateWalletService
  ALLOWED_OWNER_TYPES = %w[organization contributor].freeze

  def self.call(owner_type:, owner_id:)
    owner_type = owner_type.to_s
    raise ArgumentError, "invalid owner_type" unless ALLOWED_OWNER_TYPES.include?(owner_type)

    applied, wallet = WalletsRepository.create_if_not_exists(
      owner_type: owner_type,
      owner_id: owner_id,
      balance_cents: 0,
      available_cents: 0,
      locked_cents: 0,
      version: 1
    )

    # For automatic creation we prefer idempotent behaviour: return existing wallet
    wallet
  end
end
