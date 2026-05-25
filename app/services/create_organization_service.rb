class CreateOrganizationService
  def self.call(attrs)
    id = OrganizationsRepository.create(attrs)
    organization = OrganizationsRepository.find(id)
    wallet = CreateWalletService.call(owner_type: "organization", owner_id: id)

    {
      organization: organization,
      wallet: wallet
    }
  end
end
