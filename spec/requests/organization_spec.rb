require 'rails_helper'

RSpec.describe "Organizations", type: :request do

  params = {
    organization: {
      name: "Test Organization",
      cnpj: "12345678000195",
      status: "active",
      contact_email: "contact@example.com",
      webhook_url: "https://example.com/webhook",
      api_key_hash: "hashed_api_key"
    }
  }

  describe "POST organizations/" do
    it "returns http success" do
      post "/organizations", params: params
      expect(response).to have_http_status(:success)
    end
  end

end
