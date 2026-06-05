require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:org_id) { SecureRandom.uuid }

  let(:campaign_a) { { campaign_id: SecureRandom.uuid, name: "Campanha A", goal_cents: 500_000, raised_cents: 250_000, status: "active" } }
  let(:campaign_b) { { campaign_id: SecureRandom.uuid, name: "Campanha B", goal_cents: 1_000_000, raised_cents: 800_000, status: "completed" } }
  let(:campaign_c) { { campaign_id: SecureRandom.uuid, name: "Campanha C", goal_cents: 200_000, raised_cents: 0, status: "draft" } }

  before(:each) do
    truncate_cassandra!

    OrganizationsRepository.create(
      organization_id: org_id,
      name: "Minha Ong",
      cnpj: "11222333000181",
      status: "active",
      contact_email: "contato@minhaong.com.br"
    )
    CreateWalletService.call(owner_type: "organization", owner_id: org_id)

    MembershipsRepository.create(
      organization_id: org_id,
      contributor_id: SecureRandom.uuid,
      membership_id: SecureRandom.uuid,
      status: "active"
    )
    MembershipsRepository.create(
      organization_id: org_id,
      contributor_id: SecureRandom.uuid,
      membership_id: SecureRandom.uuid,
      status: "active"
    )

    [campaign_a, campaign_b, campaign_c].each do |c|
      c[:organization_id] = org_id
      CampaignsRepository.create(c)
    end

    ExpenseEntriesRepository.create(
      organization_id: org_id, campaign_id: campaign_a[:campaign_id],
      entry_id: SecureRandom.uuid, description: "Material", amount_cents: 10_000,
      category: "materials", expense_date: Date.today, status: "approved"
    )
    ExpenseEntriesRepository.create(
      organization_id: org_id, campaign_id: campaign_a[:campaign_id],
      entry_id: SecureRandom.uuid, description: "Transporte", amount_cents: 5_000,
      category: "transport", expense_date: Date.today, status: "approved"
    )
    ExpenseEntriesRepository.create(
      organization_id: org_id, campaign_id: campaign_b[:campaign_id],
      entry_id: SecureRandom.uuid, description: "Equipamento", amount_cents: 100_000,
      category: "equipment", expense_date: Date.today, status: "approved"
    )

    tx_id = SecureRandom.uuid
    TransactionsByOwnerRepository.insert(
      owner_type: "organization", owner_id: org_id,
      transaction_id: tx_id, created_at: Time.now.utc - 3600,
      amount_cents: 150_00, currency: "BRL",
      transaction_type: "credit", status: "captured",
      campaign_id: campaign_a[:campaign_id],
      idempotency_key: SecureRandom.uuid
    )
    TransactionsByCampaignRepository.insert(
      owner_type: "organization", owner_id: org_id,
      transaction_id: tx_id, created_at: Time.now.utc - 3600,
      amount_cents: 150_00, currency: "BRL",
      transaction_type: "credit", status: "captured",
      campaign_id: campaign_a[:campaign_id],
      idempotency_key: SecureRandom.uuid
    )

    tx_id2 = SecureRandom.uuid
    TransactionsByOwnerRepository.insert(
      owner_type: "organization", owner_id: org_id,
      transaction_id: tx_id2, created_at: Time.now.utc - 7200,
      amount_cents: 50_00, currency: "BRL",
      transaction_type: "credit", status: "captured",
      campaign_id: campaign_b[:campaign_id],
      idempotency_key: SecureRandom.uuid
    )
    TransactionsByCampaignRepository.insert(
      owner_type: "organization", owner_id: org_id,
      transaction_id: tx_id2, created_at: Time.now.utc - 7200,
      amount_cents: 50_00, currency: "BRL",
      transaction_type: "credit", status: "captured",
      campaign_id: campaign_b[:campaign_id],
      idempotency_key: SecureRandom.uuid
    )

    CreditLinesRepository.create_if_not_exists(
      credit_id: SecureRandom.uuid, organization_id: org_id,
      limit_cents: 2_000_000, available_cents: 1_500_000,
      annual_rate: BigDecimal("0.05"), status: "active"
    )
  end

  describe "GET /organizations/:id/dashboard" do
    it "returns aggregated dashboard metrics" do
      get "/organizations/#{org_id}/dashboard"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["organization_id"]).to eq(org_id)
      expect(body["name"]).to eq("Minha Ong")

      metrics = body["metrics"]
      expect(metrics["total_raised_cents"]).to eq(1_050_000)
      expect(metrics["total_spent_cents"]).to eq(115_000)
      expect(metrics["balance_cents"]).to eq(935_000)
      expect(metrics["active_campaigns"]).to eq(1)
      expect(metrics["total_campaigns"]).to eq(3)
      expect(metrics["member_count"]).to eq(2)
      expect(metrics["credit_line_available_cents"]).to eq(1_500_000)

      camps = body["campaigns"]
      expect(camps.size).to eq(3)

      camp_a = camps.find { |c| c["campaign_id"] == campaign_a[:campaign_id] }
      expect(camp_a["raised_cents"]).to eq(250_000)
      expect(camp_a["spent_cents"]).to eq(15_000)
      expect(camp_a["balance_cents"]).to eq(235_000)
      expect(camp_a["progress_pct"]).to eq(50.0)

      camp_b = camps.find { |c| c["campaign_id"] == campaign_b[:campaign_id] }
      expect(camp_b["raised_cents"]).to eq(800_000)
      expect(camp_b["spent_cents"]).to eq(100_000)
      expect(camp_b["balance_cents"]).to eq(700_000)
      expect(camp_b["progress_pct"]).to eq(80.0)

      camp_c = camps.find { |c| c["campaign_id"] == campaign_c[:campaign_id] }
      expect(camp_c["raised_cents"]).to eq(0)
      expect(camp_c["spent_cents"]).to eq(0)
      expect(camp_c["balance_cents"]).to eq(0)
      expect(camp_c["progress_pct"]).to eq(0.0)

      txns = body["recent_transactions"]
      expect(txns.size).to eq(2)
      expect(txns[0]["amount_cents"]).to eq(150_00)
      expect(txns[1]["amount_cents"]).to eq(50_00)
    end

    it "returns 404 for unknown organization" do
      get "/organizations/00000000-0000-0000-0000-000000000000/dashboard"
      expect(response).to have_http_status(:not_found)
    end
  end
end
