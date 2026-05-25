require 'rails_helper'

RSpec.describe "Contributors", type: :request do
  describe "POST /contributors" do
    it "returns created" do
      host! "127.0.0.1"

      post "/contributors", params: {
        contributor: {
          name: "Test Contributor",
          email: "contributor@example.com",
          cpf: "12345678901",
          phone: "+5511999999999",
          status: "active"
        }
      }, as: :json

      warn "status=#{response.status} content_type=#{response.media_type} body=#{response.body}" unless response.status == 201

      body = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(body["contributor"]["name"]).to eq("Test Contributor")
    end
  end
end
