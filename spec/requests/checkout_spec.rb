require 'rails_helper'

RSpec.describe "Checkout", type: :request do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }
  let(:campaign_id) do
    post "/organizations/#{org_id}/campaigns", params: { campaign: { name: "Checkout Spec", goal_cents: 100000 } }
    JSON.parse(response.body)["campaign_id"]
  end

  let(:valid_params) do
    {
      checkout: {
        campaign_id: campaign_id,
        amount_cents: 5000,
        currency: "BRL",
        idempotency_key: "spec_key_#{SecureRandom.uuid}",
        contributor: { name: "João Silva", email: "joao@spec.com" },
        payment: { method: "card" }
      }
    }
  end

  describe "POST /api/v1/public/checkout" do
    it "returns 201 with valid data" do
      post "/api/v1/public/checkout", params: valid_params
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body).to have_key("transaction_id")
      expect(body["contributor"]["name"]).to eq("João Silva")
      expect(body["contributor"]["email"]).to eq("joao@spec.com")
    end

    it "reuses existing contributor by email" do
      post "/api/v1/public/checkout", params: valid_params
      expect(response).to have_http_status(:created)
      first = JSON.parse(response.body)

      same_email = valid_params.deep_dup
      same_email[:checkout][:idempotency_key] = "spec_key_#{SecureRandom.uuid}"
      post "/api/v1/public/checkout", params: same_email
      expect(response).to have_http_status(:created)
      second = JSON.parse(response.body)

      expect(second["contributor"]["contributor_id"]).to eq(first["contributor"]["contributor_id"])
    end

    it "returns 200 with already_processed for duplicate idempotency key" do
      post "/api/v1/public/checkout", params: valid_params
      expect(response).to have_http_status(:created)

      post "/api/v1/public/checkout", params: valid_params
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("already_processed")
    end

    it "returns 422 for unknown campaign" do
      invalid = valid_params.deep_dup
      invalid[:checkout][:campaign_id] = "00000000-0000-0000-0000-000000000000"
      post "/api/v1/public/checkout", params: invalid
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
