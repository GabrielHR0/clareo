require 'rails_helper'

RSpec.describe "Contributors", type: :request do
  describe "GET /contributors" do
    it "returns a list of contributors" do
      host! "127.0.0.1"
      get "/contributors", as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
    end
  end

  describe "GET /contributors/:id" do
    it "returns 404 for unknown contributor" do
      host! "127.0.0.1"
      get "/contributors/00000000-0000-0000-0000-000000000000", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
