require 'rails_helper'

RSpec.describe "UserAuth", type: :request do
  let(:email) { "auth_#{SecureRandom.hex(8)}@example.com" }
  let(:password) { "password12345678" }
  let(:name) { "Test User" }

  describe "POST /auth/register" do
    it "creates user, contributor, wallet and returns token" do
      post "/auth/register", params: { email: email, password: password, name: name }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["user"]).to include("user_id", "email", "name", "contributor_id")
      expect(body["user"]["email"]).to eq(email)
      expect(body["user"]["name"]).to eq(name)
      expect(body["contributor"]).to include("contributor_id", "name", "email")
      expect(body["wallet"]).to include("owner_type", "owner_id")
      expect(body["token"]).to be_present
    end

    it "rejects duplicate email" do
      post "/auth/register", params: { email: email, password: password, name: name }
      expect(response).to have_http_status(:created)
      post "/auth/register", params: { email: email, password: password, name: name }
      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]).to eq("Email already registered")
    end

    it "requires email" do
      post "/auth/register", params: { password: password, name: name }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires password" do
      post "/auth/register", params: { email: email, name: name }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires password length >= 8" do
      post "/auth/register", params: { email: email, password: "short", name: name }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /auth/login" do
    before do
      post "/auth/register", params: { email: email, password: password, name: name }
    end

    it "logs in with valid credentials" do
      post "/auth/login", params: { email: email, password: password }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user"]).to include("user_id", "email", "name")
      expect(body["token"]).to be_present
    end

    it "rejects wrong password" do
      post "/auth/login", params: { email: email, password: "wrong_password_12345" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects non-existent email" do
      post "/auth/login", params: { email: "nonexistent_#{SecureRandom.hex(8)}@example.com", password: password }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /auth/me" do
    let(:user_id) { SecureRandom.uuid }
    let(:contributor_id) { SecureRandom.uuid }

    before do
      UsersRepository.create(user_id: user_id, email: email, password_hash: BCrypt::Password.create(password), name: name)
      ContributorsRepository.create(contributor_id: contributor_id, name: name, email: email)
      UsersRepository.update(user_id, contributor_id: contributor_id)
      allow_any_instance_of(ApplicationController).to receive(:skip_auth?).and_return(false)
    end

    let(:token) { JwtAuth.encode(user_id: user_id, email: email) }

    it "returns current user data" do
      get "/auth/me", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user"]).to include("user_id", "email", "name", "contributor_id")
      expect(body["user"]["email"]).to eq(email)
    end

    it "returns 401 without token" do
      get "/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid token" do
      get "/auth/me", headers: { "Authorization" => "Bearer invalid_token_123" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /auth/me/contributor" do
    let(:user_id) { SecureRandom.uuid }
    let(:contributor_id) { SecureRandom.uuid }

    before do
      UsersRepository.create(user_id: user_id, email: email, password_hash: BCrypt::Password.create(password), name: name)
      ContributorsRepository.create(contributor_id: contributor_id, name: name, email: email)
      UsersRepository.update(user_id, contributor_id: contributor_id)
      allow_any_instance_of(ApplicationController).to receive(:skip_auth?).and_return(false)
    end

    let(:token) { JwtAuth.encode(user_id: user_id, email: email) }

    it "returns contributor data for authenticated user" do
      get "/auth/me/contributor", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("contributor_id", "name", "email", "status")
      expect(body["name"]).to eq(name)
      expect(body["email"]).to eq(email)
    end

    it "returns 401 without token" do
      get "/auth/me/contributor"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
