require "securerandom"
require "digest"

class CreateOrganizationService
  def self.call(attrs)
    api_key = SecureRandom.urlsafe_base64(32)
    api_key_hash = Digest::SHA256.base64digest(api_key)

    id = OrganizationsRepository.create(attrs.merge(api_key_hash: api_key_hash))
    organization = OrganizationsRepository.find(id)
    wallet = CreateWalletService.call(owner_type: "organization", owner_id: id)

    {
      organization: organization,
      wallet: wallet,
      api_key: api_key
    }
  end
end
