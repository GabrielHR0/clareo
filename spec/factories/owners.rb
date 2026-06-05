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

  factory :campaign do
    transient do
      organization_id { nil }
      name { Faker::Marketing.buzzwords }
    end

    initialize_with do
      org_id = organization_id
      attrs = { organization_id: org_id, name: name, goal_cents: Faker::Number.between(from: 10000, to: 1000000) }
      CampaignService.create(attrs)
    end
  end

  factory :expense do
    transient do
      organization_id { nil }
      campaign_id { nil }
      description { Faker::Lorem.sentence }
    end

    initialize_with do
      attrs = {
        organization_id: organization_id,
        campaign_id: campaign_id,
        description: description,
        amount_cents: Faker::Number.between(from: 100, to: 50000),
        category: %w[materials labor transport equipment supplies].sample,
        expense_date: Faker::Date.backward(days: 30)
      }
      ExpenseService.create(attrs)
    end
  end

  factory :recurring_donation do
    transient do
      organization_id { nil }
      contributor_id { nil }
    end

    initialize_with do
      attrs = {
        organization_id: organization_id,
        contributor_id: contributor_id,
        amount_cents: Faker::Number.between(from: 1000, to: 50000),
        interval_days: 30,
        payment_method: "wallet"
      }
      RecurringDonationService.create(attrs)
    end
  end
end
