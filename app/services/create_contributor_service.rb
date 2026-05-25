class CreateContributorService
  def self.call(attrs)
    id = ContributorsRepository.create(attrs)
    contributor = ContributorsRepository.find(id)
    wallet = CreateWalletService.call(owner_type: "contributor", owner_id: id)

    {
      contributor: contributor,
      wallet: wallet
    }
  end
end
