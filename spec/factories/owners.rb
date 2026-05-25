FactoryBot.define do
  factory :organization do
    transient do
      initial_balance_cents { 10_000 }
    end

    initialize_with do
      id = OrganizationsRepository.create(name: Faker::Company.name)
      OrganizationsRepository.find(id)
    end

    after(:create) do |org, evaluator|
      # ensure wallet exists and set initial balance
      wallet = CreateWalletService.call(owner_type: "organization", owner_id: org[:organization_id])
      WalletsRepository.update_balances_if_version(
        owner_id: org[:organization_id],
        owner_type: "organization",
        balance_cents: evaluator.initial_balance_cents,
        available_cents: evaluator.initial_balance_cents,
        locked_cents: 0,
        expected_version: wallet[:version]
      )
    end
  end

  factory :contributor do
    initialize_with do
      id = ContributorsRepository.create(name: Faker::Name.name)
      ContributorsRepository.find(id)
    end
  end
end
