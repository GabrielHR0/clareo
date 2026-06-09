require 'rails_helper'

RSpec.describe "UserAssociations", type: :request do
  let(:email) { "assoc_#{SecureRandom.hex(8)}@example.com" }
  let(:user_id) { SecureRandom.uuid }
  let(:contributor_id) { SecureRandom.uuid }
  let(:org_id) { SecureRandom.uuid }
  let(:password_hash) { BCrypt::Password.create("password12345678") }

  before do
    UsersRepository.create(user_id: user_id, email: email, password_hash: password_hash, name: "Test User")
    ContributorsRepository.create(contributor_id: contributor_id, name: "Test User", email: email)
    UsersRepository.update(user_id, contributor_id: contributor_id)
    OrganizationsRepository.create(organization_id: org_id, name: "Test Organization")
    allow_any_instance_of(ApplicationController).to receive(:skip_auth?).and_return(false)
  end

  let(:token) { JwtAuth.encode(user_id: user_id, email: email) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/associations" do
    it "returns empty list when no associations" do
      get "/api/v1/associations", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns 401 without token" do
      get "/api/v1/associations"
      expect(response).to have_http_status(:unauthorized)
    end

    context "with existing association" do
      let(:membership_id) { SecureRandom.uuid }

      before do
        MembershipsRepository.create(
          membership_id: membership_id,
          organization_id: org_id,
          contributor_id: contributor_id,
          status: "active"
        )
      end

      it "returns list with association" do
        get "/api/v1/associations", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.length).to eq(1)
        expect(json[0]).to include("organization_id", "contributor_id", "membership_id", "status")
        expect(json[0]["organization_id"]).to eq(org_id)
      end
    end
  end

  describe "POST /api/v1/associations" do
    it "creates an association" do
      post "/api/v1/associations",
           params: { organization_id: org_id },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to include("membership_id", "organization_id")
      expect(json["organization_id"]).to eq(org_id)
    end

    it "returns 422 without organization_id" do
      post "/api/v1/associations",
           params: {},
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("organization_id required")
    end

    it "returns 409 when already associated" do
      post "/api/v1/associations",
           params: { organization_id: org_id },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:created)

      post "/api/v1/associations",
           params: { organization_id: org_id },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "DELETE /api/v1/associations/:organization_id" do
    before do
      post "/api/v1/associations",
           params: { organization_id: org_id },
           headers: headers,
           as: :json
    end

    it "removes an association" do
      delete "/api/v1/associations/#{org_id}", headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "returns empty list after removal" do
      delete "/api/v1/associations/#{org_id}", headers: headers

      get "/api/v1/associations", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns 401 without token" do
      delete "/api/v1/associations/#{org_id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
