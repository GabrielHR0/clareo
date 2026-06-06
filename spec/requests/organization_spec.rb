require 'rails_helper'

RSpec.describe "Organizations", type: :request do
  describe "POST /organizations" do
    it "returns http success with api_key" do
      params = {
        organization: {
          name: "Test Organization",
          cnpj: "12345678000195",
          status: "active",
          contact_email: "contact@example.com",
          webhook_url: "https://example.com/webhook"
        }
      }

      post "/organizations", params: params
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to have_key("api_key")
      expect(body["api_key"].length).to be >= 32
    end
  end
end
