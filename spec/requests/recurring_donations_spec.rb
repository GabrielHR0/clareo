require 'rails_helper'

RSpec.describe "RecurringDonations", type: :request do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }
  let(:contrib_id) { "e05201ae-290a-48c8-8972-dbc3cd85fd90" }

  let(:valid_params) do
    {
      recurring_donation: {
        organization_id: org_id,
        amount_cents: 5000,
        interval_days: 30,
        payment_method: "wallet"
      }
    }
  end

  describe "POST /contributors/:contributor_id/recurring_donations" do
    it "creates a recurring donation" do
      post "/contributors/#{contrib_id}/recurring_donations", params: valid_params.to_json, headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to have_key("recurring_id")
      expect(body["organization_id"]).to eq(org_id)
    end

    it "rejects without organization_id" do
      post "/contributors/#{contrib_id}/recurring_donations", params: { recurring_donation: { amount_cents: 5000 } }.to_json, headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /contributors/:contributor_id/recurring_donations" do
    it "lists recurring donations for a contributor" do
      post "/contributors/#{contrib_id}/recurring_donations", params: valid_params.to_json, headers: { "Content-Type" => "application/json" }
      created_id = JSON.parse(response.body)["recurring_id"]

      get "/contributors/#{contrib_id}/recurring_donations"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.size).to be >= 1

      created = body.find { |d| d["recurring_id"] == created_id }
      expect(created).to_not be_nil
      expect(created["status"]).to eq("active")
    end
  end

  describe "DELETE /contributors/:contributor_id/recurring_donations/:id" do
    it "cancels a recurring donation" do
      post "/contributors/#{contrib_id}/recurring_donations", params: valid_params.to_json, headers: { "Content-Type" => "application/json" }
      recurring_id = JSON.parse(response.body)["recurring_id"]

      delete "/contributors/#{contrib_id}/recurring_donations/#{recurring_id}?organization_id=#{org_id}"
      expect(response).to have_http_status(:ok)

      get "/contributors/#{contrib_id}/recurring_donations"
      donations = JSON.parse(response.body)
      cancelled = donations.find { |d| d["recurring_id"] == recurring_id }
      expect(cancelled["status"]).to eq("cancelled")
    end

    it "returns 404 for unknown donation" do
      delete "/contributors/#{contrib_id}/recurring_donations/00000000-0000-0000-0000-000000000000?organization_id=#{org_id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
