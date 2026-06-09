require "rails_helper"

RSpec.describe "Finance E2E flows", type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:headers) { { "HOST" => "127.0.0.1" } }

  def json
    JSON.parse(response.body)
  end

  def create_org!
    post "/organizations", params: {
      organization: { organization_id: org_id, name: "Test E2E Org" }
    }, as: :json, headers: headers
    expect(response).to have_http_status(:created)
  end

  def create_campaign!(name: "Campaign", goal: 100000)
    post "/organizations/#{org_id}/campaigns", params: {
      campaign: { name: name, goal_cents: goal }
    }, as: :json, headers: headers
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["campaign_id"]
  end

  def donate!(campaign_id:, amount_cents:, key: nil)
    key ||= "donate_#{org_id}_#{campaign_id}_#{SecureRandom.uuid}"
    post "/owners/organization/#{org_id}/transactions", params: {
      transaction: {
        amount_cents: amount_cents,
        currency: "BRL",
        transaction_type: "credit",
        campaign_id: campaign_id,
        idempotency_key: key
      }
    }, as: :json, headers: headers
    expect(response).to have_http_status(:created)
  end

  # ---------------------------------------------------------------------------
  # Flow 1: Donation → Redemption → Expense → Accountability consistency
  # ---------------------------------------------------------------------------
  describe "donation -> redemption -> expense -> accountability" do
    before { create_org! }
    let(:campaign_id) { create_campaign! }

    it "maintains mathematical consistency across the full lifecycle" do
      # ---- 1. Donate 10000 (R$ 100,00) to the campaign ----
      donate!(campaign_id: campaign_id, amount_cents: 10000)

      # Verify campaign raised/held
      get "/organizations/#{org_id}/campaigns/#{campaign_id}", headers: headers
      expect(response).to have_http_status(:ok)
      campaign = json
      expect(campaign["raised_cents"]).to eq(10000)
      expect(campaign["held_cents"]).to eq(10000)

      # Wallet should NOT have been credited (donations bypass wallet)
      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["balance_cents"]).to eq(0)

      # ---- 2. Donate another 5000 ----
      donate!(campaign_id: campaign_id, amount_cents: 5000)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}", headers: headers
      campaign = json
      expect(campaign["raised_cents"]).to eq(15000)
      expect(campaign["held_cents"]).to eq(15000)

      # ---- 3. Redeem 8000 (resgatar R$ 80,00) ----
      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: 8000
      }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)
      campaign_after_redeem = json
      expect(campaign_after_redeem["held_cents"]).to eq(7000)
      expect(campaign_after_redeem["raised_cents"]).to eq(15000) # unchanged

      # Wallet should now have 8000 (redemption credits org wallet)
      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(8000)

      # Transaction list should contain the redemption credit with campaign context
      get "/owners/organization/#{org_id}/transactions?limit=50", headers: headers
      expect(response).to have_http_status(:ok)
      txs = json
      redemption_tx = txs.find { |t| t.dig("metadata", "redemption") == "true" }
      expect(redemption_tx).to_not be_nil
      expect(redemption_tx["amount_cents"]).to eq(8000)

      # ---- 4. Create an expense of 3000 ----
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses", params: {
        expense: { description: "Camping supplies", amount_cents: 3000 }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      # ---- 5. Get accountability and verify numbers ----
      get "/api/v1/public/campaigns/#{campaign_id}/accountability", headers: headers
      expect(response).to have_http_status(:ok)
      acc = json

      expect(acc.dig("campaign", "raised_cents")).to eq(15000)
      expect(acc.dig("campaign", "held_cents")).to eq(7000)
      expect(acc.dig("summary", "total_raised")).to eq(15000)
      expect(acc.dig("summary", "total_spent")).to eq(3000)
      expect(acc.dig("summary", "total_redemption")).to eq(8000)
      # balance = raised - spent - redemption = 15000 - 3000 - 8000 = 4000
      expect(acc.dig("summary", "balance")).to eq(4000)
      expect(acc.dig("summary", "total_held")).to eq(7000)

      # Expenses should include both the expense and the redemption entry
      expenses = acc["expenses"]
      expect(expenses.size).to eq(2)
      redemption_entry = expenses.find { |e| e["type"] == "redemption" }
      expense_entry = expenses.find { |e| e["type"] == "expense" }
      expect(redemption_entry).to_not be_nil
      expect(redemption_entry["amount_cents"]).to eq(8000)
      expect(expense_entry).to_not be_nil
      expect(expense_entry["amount_cents"]).to eq(3000)
      expect(expense_entry["description"]).to eq("Camping supplies")

      # ---- 6. Redeem remaining 7000 (full redemption) ----
      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: 7000
      }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}", headers: headers
      expect(json["held_cents"]).to eq(0)

      # Wallet should now have 15000 (8000 + 7000)
      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(15000)

      # Final accountability: balance = 15000 - 3000 - 15000 = -3000 (overspent)
      get "/api/v1/public/campaigns/#{campaign_id}/accountability", headers: headers
      acc = json
      expect(acc.dig("summary", "total_redemption")).to eq(15000)
      expect(acc.dig("summary", "balance")).to eq(-3000)

      # ---- 7. Spend more than available in wallet (should fail) ----
      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 20000,
          currency: "BRL",
          transaction_type: "debit",
          idempotency_key: "withdraw_#{org_id}_overspend"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["status"]).to eq("insufficient_funds")

      # Wallet still has 15000 (unchanged)
      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(15000)
    end
  end

  # ---------------------------------------------------------------------------
  # Flow 2: Redemption edge cases
  # ---------------------------------------------------------------------------
  describe "redemption edge cases" do
    before { create_org! }
    let(:campaign_id) { create_campaign! }

    it "rejects redemption of zero cents" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: 0
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects redemption of negative amount" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: -100
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects redemption when held_cents is insufficient" do
      donate!(campaign_id: campaign_id, amount_cents: 500)

      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: 1000
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to match(/Insufficient held funds/i)
    end

    it "rejects redemption for non-existent campaign" do
      put "/organizations/#{org_id}/campaigns/00000000-0000-0000-0000-000000000000/redeem", params: {
        amount_cents: 100
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "creates a redemption with a custom description" do
      donate!(campaign_id: campaign_id, amount_cents: 5000)

      put "/organizations/#{org_id}/campaigns/#{campaign_id}/redeem", params: {
        amount_cents: 3000,
        description: "Resgate para pagar fornecedor"
      }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)

      get "/api/v1/public/campaigns/#{campaign_id}/accountability", headers: headers
      expect(response).to have_http_status(:ok)
      exp = json["expenses"].find { |e| e["type"] == "redemption" }
      expect(exp["description"]).to eq("Resgate para pagar fornecedor")
      expect(exp["amount_cents"]).to eq(3000)
    end
  end

  # ---------------------------------------------------------------------------
  # Flow 3: Wallet deposit, withdraw, idempotency, enrichment
  # ---------------------------------------------------------------------------
  describe "wallet operations" do
    before { create_org! }

    it "auto-creates wallet on first GET" do
      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["balance_cents"]).to eq(0)
      expect(json["available_cents"]).to eq(0)
    end

    it "deposit increases balance" do
      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 50000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "dep_#{org_id}_1"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(50000)
      expect(json["available_cents"]).to eq(50000)
    end

    it "withdraw decreases balance" do
      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 30000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "dep_#{org_id}_wd"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 10000,
          currency: "BRL",
          transaction_type: "debit",
          idempotency_key: "wd_#{org_id}_1"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(20000)
      expect(json["available_cents"]).to eq(20000)
    end

    it "insufficient funds returns 422" do
      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 100,
          currency: "BRL",
          transaction_type: "debit",
          idempotency_key: "wd_#{org_id}_insuf"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "idempotency key prevents duplicate processing" do
      key = "idemp_#{org_id}_unique"

      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 10000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: key
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)
      first_tx_id = json["transaction_id"]

      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 10000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: key
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("already_processed")
      expect(json["transaction_id"]).to eq(first_tx_id)

      get "/owners/organization/#{org_id}/wallet", headers: headers
      expect(json["balance_cents"]).to eq(10000)
    end

    it "enriches transactions with campaign_name" do
      c_id = create_campaign!(name: "Nome da Campanha")

      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 7777,
          currency: "BRL",
          transaction_type: "credit",
          campaign_id: c_id,
          idempotency_key: "enrich_#{org_id}"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      get "/owners/organization/#{org_id}/transactions?limit=50", headers: headers
      expect(response).to have_http_status(:ok)
      txs = json
      donation_tx = txs.find { |t| t["campaign_id"] == c_id }
      expect(donation_tx["campaign_name"]).to eq("Nome da Campanha")
    end
  end

  # ---------------------------------------------------------------------------
  # Flow 4: Credit lines — request, bills, payment
  # ---------------------------------------------------------------------------
  describe "credit line lifecycle" do
    let(:api_prefix) { "/api/v1" }
    before { create_org! }

    it "requests credit (new line), generates bills, and pays them" do
      # ---- 1. Request credit (new line) ----
      get "#{api_prefix}/credit_lines/#{org_id}/request/50000", headers: headers
      expect(response).to have_http_status(:ok), "Expected 200 got #{response.status}: #{response.body}"
      result = json
      expect(result["status"]).to eq("approved")
      expect(result["limit_cents"]).to eq(50000)
      first_credit_id = result["credit_id"]

      # Verify credit line exists
      get "/credit_lines/#{first_credit_id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("active")
      expect(json["limit_cents"]).to eq(50000)
      expect(json["available_cents"]).to eq(50000)

      # ---- 2. Use credit (draw 20000) ----
      post "/credit_lines/#{first_credit_id}/use", params: { amount_cents: 20000 }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)

      get "/credit_lines/#{first_credit_id}", headers: headers
      expect(json["used_cents"]).to eq(20000)
      expect(json["available_cents"]).to eq(30000)
      expect(json["limit_cents"]).to eq(50000)

      # ---- 3. Generate monthly bills ----
      CreditBillingService.generate_monthly_bills(org_id)
      get "#{api_prefix}/credit_lines/#{org_id}/bills", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
      expect(json.size).to be >= 1
      bill = json.find { |b| b["credit_id"] == first_credit_id }
      expect(bill).to_not be_nil
      expect(bill["amount_cents"]).to eq(20000)
      expect(bill["status"]).to eq("pending")
      expect(bill["paid_cents"]).to eq(0)
      bill_id = bill["bill_id"]

      # ---- 4. Pay bill partially ----
      post "#{api_prefix}/credit_lines/#{org_id}/bills/#{bill_id}/pay", params: { amount_cents: 8000 }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)
      pay_result = json
      expect(pay_result["status"]).to eq("ok")
      expect(pay_result["paid"]).to eq(8000)
      expect(pay_result["new_status"]).to eq("partial")

      # Verify bill updated
      get "#{api_prefix}/credit_lines/#{org_id}/bills", headers: headers
      updated_bill = json.find { |b| b["bill_id"] == bill_id }
      expect(updated_bill["paid_cents"]).to eq(8000)
      expect(updated_bill["status"]).to eq("partial")

      # Credit line should reflect repayment
      get "/credit_lines/#{first_credit_id}", headers: headers
      expect(json["used_cents"]).to eq(12000)
      expect(json["available_cents"]).to eq(38000)

      # ---- 5. Pay remaining balance ----
      post "#{api_prefix}/credit_lines/#{org_id}/bills/#{bill_id}/pay", params: { amount_cents: 12000 }, as: :json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("ok")
      expect(json["paid"]).to eq(12000)
      expect(json["new_status"]).to eq("paid")

      get "/credit_lines/#{first_credit_id}", headers: headers
      expect(json["used_cents"]).to eq(0)
      expect(json["available_cents"]).to eq(50000)

      # ---- 6. Pay already-paid bill -> error ----
      post "#{api_prefix}/credit_lines/#{org_id}/bills/#{bill_id}/pay", params: { amount_cents: 1 }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "extends credit limit on second request" do
      get "#{api_prefix}/credit_lines/#{org_id}/request/30000", headers: headers
      expect(response).to have_http_status(:ok)
      first = json
      expect(first["limit_cents"]).to eq(30000)

      get "#{api_prefix}/credit_lines/#{org_id}/request/20000", headers: headers
      expect(response).to have_http_status(:ok)
      second = json
      expect(second["credit_id"]).to eq(first["credit_id"])
      expect(second["limit_cents"]).to eq(50000)
    end

    it "rejects zero/negative credit request" do
      get "#{api_prefix}/credit_lines/#{org_id}/request/0", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      get "#{api_prefix}/credit_lines/#{org_id}/request/-100", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects use_credit when insufficient" do
      get "#{api_prefix}/credit_lines/#{org_id}/request/10000", headers: headers
      expect(response).to have_http_status(:ok)
      credit_id = json["credit_id"]

      post "/credit_lines/#{credit_id}/use", params: { amount_cents: 99999 }, as: :json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ---------------------------------------------------------------------------
  # Flow 5: Finance Overview — aggregates everything
  # ---------------------------------------------------------------------------
  describe "finance overview endpoint" do
    before do
      create_org!
      @fo_campaign_id = create_campaign!(name: "Finance Overview Campaign")

      # Donate to campaign
      donate!(campaign_id: @fo_campaign_id, amount_cents: 25000)

      # Deposit directly into wallet
      post "/owners/organization/#{org_id}/transactions", params: {
        transaction: {
          amount_cents: 100000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "fo_dep_#{org_id}"
        }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      # Request credit
      get "/api/v1/credit_lines/#{org_id}/request/50000", headers: headers
      expect(response).to have_http_status(:ok)

      # Add a payment method
      post "/owners/organization/#{org_id}/payment_methods", params: {
        method_type: "pix",
        details: { key: "test@example.com" },
        is_default: true
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it "returns aggregated financial data" do
      get "/finance/organization/#{org_id}", headers: headers
      expect(response).to have_http_status(:ok)
      fin = json

      expect(fin["wallet"]["balance_cents"]).to eq(100000)

      expect(fin["credit_lines"]).to be_an(Array)
      expect(fin["credit_lines"].size).to be >= 1
      expect(fin["credit_lines"].first["limit_cents"]).to eq(50000)

      expect(fin["bills"]).to be_an(Array)

      expect(fin["payment_methods"]).to be_an(Array)
      expect(fin["payment_methods"].size).to be >= 1
      pix_method = fin["payment_methods"].find { |pm| pm["method_type"] == "pix" }
      expect(pix_method).to_not be_nil

      expect(fin["transactions"]).to be_an(Array)
      campaign_tx = fin["transactions"].find { |t| t["campaign_id"] == @fo_campaign_id }
      expect(campaign_tx).to_not be_nil
      expect(campaign_tx["campaign_name"]).to eq("Finance Overview Campaign")
    end
  end

  # ---------------------------------------------------------------------------
  # Flow 6: Payment methods CRUD
  # ---------------------------------------------------------------------------
  describe "payment methods" do
    before { create_org! }

    it "creates, lists, and deletes" do
      get "/owners/organization/#{org_id}/payment_methods", headers: headers
      expect(json).to eq([])

      post "/owners/organization/#{org_id}/payment_methods", params: {
        method_type: "credit_card",
        details: { last4: "1234", brand: "visa" },
        is_default: true
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)
      pm = json
      expect(pm["method_type"]).to eq("credit_card")
      expect(pm["details"]).to include("last4" => "1234", "brand" => "visa")
      expect(pm["is_default"]).to be true
      pm_id = pm["method_id"]

      get "/owners/organization/#{org_id}/payment_methods", headers: headers
      expect(json.size).to eq(1)

      post "/owners/organization/#{org_id}/payment_methods", params: {
        method_type: "boleto",
        details: { barcode: "123456789" }
      }, as: :json, headers: headers
      expect(response).to have_http_status(:created)

      get "/owners/organization/#{org_id}/payment_methods", headers: headers
      expect(json.size).to eq(2)

      delete "/owners/organization/#{org_id}/payment_methods/#{pm_id}", headers: headers
      expect(response).to have_http_status(:no_content)

      get "/owners/organization/#{org_id}/payment_methods", headers: headers
      expect(json.size).to eq(1)
      expect(json.first["method_type"]).to eq("boleto")
    end
  end
end
