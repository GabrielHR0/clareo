require 'rails_helper'
require 'digest'

RSpec.describe "Authentication", type: :request do
  let(:org_id) { SecureRandom.uuid }
  let(:api_key) { SecureRandom.urlsafe_base64(32) }

  before(:each) do
    truncate_cassandra!
    api_key_hash = Digest::SHA256.base64digest(api_key)
    OrganizationsRepository.create(
      organization_id: org_id,
      name: "Authed Org",
      api_key_hash: api_key_hash
    )
  end

  describe "public endpoints" do
    it "GET /health/cassandra works without API key" do
      get "/health/cassandra"
      expect(response).to have_http_status(:ok)
    end

    it "GET /up works without API key" do
      get "/up"
      expect(response).to have_http_status(:ok)
    end

    it "GET /api/v1/public/campaigns/:id/accountability returns 404 (not 401)" do
      get "/api/v1/public/campaigns/00000000-0000-0000-0000-000000000000/accountability"
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe "auth enforcement" do
    before do
      allow_any_instance_of(ApplicationController).to receive(:skip_auth?).and_return(false)
    end

    it "returns 401 without API key" do
      get "/api/v1/organizations/#{org_id}"
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("API key required")
    end

    it "returns 401 with invalid API key" do
      get "/api/v1/organizations/#{org_id}",
          headers: { "X-API-Key" => "invalid_key_123" }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid API key")
    end

    it "returns 200 with valid API key" do
      get "/api/v1/organizations/#{org_id}",
          headers: { "X-API-Key" => api_key }
      expect(response).to have_http_status(:ok)
    end

    it "POST with valid API key on internal endpoint succeeds" do
      post "/api/v1/credit_lines",
           params: { credit_line: { organization_id: org_id, limit_cents: 100_000 } },
           headers: { "X-API-Key" => api_key }
      expect(response).to have_http_status(:created)
    end
  end
end
