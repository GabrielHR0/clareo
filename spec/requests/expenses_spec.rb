require 'rails_helper'

RSpec.describe "Expenses", type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:campaign_id) do
    OrganizationsRepository.create(organization_id: org_id, name: "Expense Spec Org", status: "active")
    post "/organizations/#{org_id}/campaigns", params: {
      campaign: { name: "Expense Spec Campaign", goal_cents: 100000 }
    }
    JSON.parse(response.body)["campaign_id"]
  end

  let(:valid_expense_params) do
    {
      expense: {
        description: "Compra de materiais",
        amount_cents: 15000,
        category: "materials",
        expense_date: "2026-06-01"
      }
    }
  end

  describe "POST /organizations/:org_id/campaigns/:campaign_id/expenses" do
    it "creates an expense entry" do
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: valid_expense_params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to have_key("entry_id")
      expect(body["organization_id"]).to eq(org_id)
    end

    it "rejects without description" do
      params = valid_expense_params.deep_dup
      params[:expense][:description] = ""

      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects non-positive amount" do
      params = valid_expense_params.deep_dup
      params[:expense][:amount_cents] = 0

      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /organizations/:org_id/campaigns/:campaign_id/expenses" do
    it "lists expenses for a campaign" do
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: valid_expense_params.to_json,
           headers: { "Content-Type" => "application/json" }
      created_id = JSON.parse(response.body)["entry_id"]

      get "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.size).to be >= 1

      found = body.find { |e| e["entry_id"] == created_id }
      expect(found).to_not be_nil
      expect(found["description"]).to eq("Compra de materiais")
    end
  end

  describe "GET /organizations/:org_id/campaigns/:campaign_id/expenses/:id" do
    it "shows an expense with attachments" do
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: valid_expense_params.to_json,
           headers: { "Content-Type" => "application/json" }
      entry_id = JSON.parse(response.body)["entry_id"]

      get "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses/#{entry_id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["entry_id"]).to eq(entry_id)
      expect(body).to have_key("attachments")
    end

    it "returns 404 for unknown expense" do
      get "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses/00000000-0000-0000-0000-000000000000"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /organizations/:org_id/campaigns/:campaign_id/expenses/:id" do
    it "deletes an expense" do
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: valid_expense_params.to_json,
           headers: { "Content-Type" => "application/json" }
      entry_id = JSON.parse(response.body)["entry_id"]

      delete "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses/#{entry_id}"
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses/#{entry_id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/public/campaigns/:campaign_id/accountability" do
    it "returns accountability report" do
      post "/organizations/#{org_id}/campaigns/#{campaign_id}/expenses",
           params: valid_expense_params.to_json,
           headers: { "Content-Type" => "application/json" }

      get "/api/v1/public/campaigns/#{campaign_id}/accountability"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("campaign")
      expect(body).to have_key("summary")
      expect(body).to have_key("expenses")
      expect(body["summary"]["total_spent"]).to be >= 15000
    end

    it "returns 404 for unknown campaign" do
      get "/api/v1/public/campaigns/00000000-0000-0000-0000-000000000000/accountability"
      expect(response).to have_http_status(:not_found)
    end
  end
end
