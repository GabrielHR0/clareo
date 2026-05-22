require 'rails_helper'

RSpec.describe "Contributors", type: :request do
  let(:params) do
    {
      contributor: {
        name: "Test Contributor",
        email: "contributor@example.com",
        cpf: "12345678901",
        phone: "+5511999999999",
        status: "active"
      }
    }
  end

  describe "POST /contributors" do
    it "returns created" do
      post "/contributors", params: params

      expect(response).to have_http_status(:created)
    end
  end
end
