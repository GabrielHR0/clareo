require 'securerandom'
require 'rails_helper'

RSpec.describe "Memberships", type: :request do
  let(:params) do
    {
      membership: {
        organization_id: SecureRandom.uuid,
        contributor_id: SecureRandom.uuid,
        status: "active"
      }
    }
  end

  describe "POST /memberships" do
    it "returns created" do
      post "/memberships", params: params

      expect(response).to have_http_status(:created)
    end
  end
end
