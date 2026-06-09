require 'rails_helper'

RSpec.describe "UserRecurringDonations", type: :request do
  let(:email) { "rd_#{SecureRandom.hex(8)}@example.com" }
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

  describe "GET /api/v1/me/recurring_donations" do
    it "returns empty list when no recurring donations" do
      get "/api/v1/me/recurring_donations", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns 401 without token" do
      get "/api/v1/me/recurring_donations"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/me/recurring_donations" do
    let(:valid_params) do
      {
        recurring_donation: {
          organization_id: org_id,
          amount_cents: 5000,
          interval_days: 30,
          payment_method: "card",
          currency: "BRL"
        }
      }
    end

    it "creates a recurring donation" do
      post "/api/v1/me/recurring_donations",
           params: valid_params,
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to include("recurring_id", "organization_id", "contributor_id")
      expect(json["organization_id"]).to eq(org_id)
    end

    it "returns 422 without organization_id" do
      post "/api/v1/me/recurring_donations",
           params: { recurring_donation: { amount_cents: 5000 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 with non-existent organization" do
      post "/api/v1/me/recurring_donations",
           params: { recurring_donation: { organization_id: SecureRandom.uuid, amount_cents: 5000 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/me/recurring_donations/:id" do
    let(:recurring_id) { SecureRandom.uuid }

    before do
      RecurringDonationsRepository.create(
        recurring_id: recurring_id,
        organization_id: org_id,
        contributor_id: contributor_id,
        amount_cents: 5000,
        interval_days: 30,
        payment_method: "card",
        currency: "BRL"
      )
    end

    it "cancels a recurring donation" do
      delete "/api/v1/me/recurring_donations/#{recurring_id}",
             params: { organization_id: org_id },
             headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for non-existent donation" do
      delete "/api/v1/me/recurring_donations/#{SecureRandom.uuid}",
             params: { organization_id: org_id },
             headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 without organization_id" do
      delete "/api/v1/me/recurring_donations/#{recurring_id}",
             headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without token" do
      delete "/api/v1/me/recurring_donations/#{recurring_id}",
             params: { organization_id: org_id }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
