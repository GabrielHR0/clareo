require 'rails_helper'

RSpec.describe "Campaigns", type: :request do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }
  let(:valid_params) do
    {
      campaign: {
        name: "Campanha Teste",
        description: "Uma campanha de teste",
        goal_cents: 100000
      }
    }
  end

  describe "POST /organizations/:org_id/campaigns" do
    it "creates a campaign with valid data" do
      post "/organizations/#{org_id}/campaigns", params: valid_params
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to have_key("campaign_id")
      expect(body).to have_key("organization_id")
    end

    it "rejects negative goal_cents" do
      post "/organizations/#{org_id}/campaigns", params: {
        campaign: { name: "Bad", goal_cents: -100 }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /organizations/:org_id/campaigns" do
    it "lists campaigns for an organization" do
      post "/organizations/#{org_id}/campaigns", params: valid_params
      get "/organizations/#{org_id}/campaigns"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.size).to be >= 1
    end
  end

  describe "GET /organizations/:org_id/campaigns/:id" do
    it "returns the campaign" do
      post "/organizations/#{org_id}/campaigns", params: valid_params
      campaign_id = JSON.parse(response.body)["campaign_id"]

      get "/organizations/#{org_id}/campaigns/#{campaign_id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Campanha Teste")
      expect(body["goal_cents"]).to eq(100000)
      expect(body["status"]).to eq("draft")
    end

    it "returns 404 for unknown campaign" do
      get "/organizations/#{org_id}/campaigns/00000000-0000-0000-0000-000000000000"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /organizations/:org_id/campaigns/:id" do
    let!(:campaign_id) do
      post "/organizations/#{org_id}/campaigns", params: valid_params
      JSON.parse(response.body)["campaign_id"]
    end

    it "updates name, description and goal_cents" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}", params: {
        campaign: { name: "Novo Nome", description: "Nova descricao", goal_cents: 99999 }
      }
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}"
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Novo Nome")
      expect(body["description"]).to eq("Nova descricao")
      expect(body["goal_cents"]).to eq(99999)
    end

    it "updates status (activates campaign)" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}", params: {
        campaign: { status: "active" }
      }
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}"
      expect(JSON.parse(response.body)["status"]).to eq("active")
    end

    it "updates tags" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}", params: {
        campaign: { tags: ["tag1", "tag2"] }
      }
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}"
      expect(JSON.parse(response.body)["tags"]).to match_array(["tag1", "tag2"])
    end

    it "does not alter fields not sent in the request" do
      put "/organizations/#{org_id}/campaigns/#{campaign_id}", params: {
        campaign: { name: "SoNome" }
      }
      expect(response).to have_http_status(:ok)

      get "/organizations/#{org_id}/campaigns/#{campaign_id}"
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("SoNome")
      expect(body["goal_cents"]).to eq(100000)
      expect(body["status"]).to eq("draft")
    end

    it "returns 422 for unknown campaign" do
      put "/organizations/#{org_id}/campaigns/00000000-0000-0000-0000-000000000000", params: {
        campaign: { name: "Nope" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
