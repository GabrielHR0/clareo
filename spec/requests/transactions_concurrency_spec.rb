require "rails_helper"

RSpec.describe "Transactions concurrency", type: :request do
  it "keeps wallets consistent under concurrent transfers" do
    # create 5 organizations with initial balances (via repository)
    org_ids = []
    5.times do
      id = OrganizationsRepository.create(name: "Org #{SecureRandom.hex(4)}")
      org = OrganizationsRepository.find(id)
      org_ids << org[:organization_id]
      wallet = CreateWalletService.call(owner_type: "organization", owner_id: org[:organization_id])
      # set initial balance to 100_000
      WalletsRepository.update_balances_if_version(
        owner_id: org[:organization_id],
        owner_type: "organization",
        balance_cents: 100_000,
        available_cents: 100_000,
        locked_cents: 0,
        expected_version: wallet[:version]
      )
    end

    initial_total = org_ids.sum { |id| WalletsRepository.find(id, "organization")[:balance_cents].to_i }

    # spawn concurrent transfers between random orgs (reduced to avoid overwhelming single-node Cassandra)
    threads = []
    10.times do
      threads << Thread.new do
        from, to = org_ids.sample(2)
        # ensure different
        if from == to
          to = (org_ids - [from]).sample
        end

        amount = [1_000, 2_000, 5_000].sample
        idempotency = SecureRandom.hex(12)

        # call service directly to stress concurrency
        res = ProcessTransactionService.call(
          owner_type: "organization",
          owner_id: from,
          amount_cents: amount,
          transaction_type: "transfer",
          idempotency_key: idempotency,
          dest_owner_type: "organization",
          dest_owner_id: to
        )

        # ignore result here; we just run the workload
      end
      sleep(0.05)
    end

    threads.each(&:join)

    final_total = org_ids.sum { |id| WalletsRepository.find(id, "organization")[:balance_cents].to_i }

    expect(final_total).to eq(initial_total)
  end
end
