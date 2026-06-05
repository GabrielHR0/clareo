require 'swagger_helper'

RSpec.describe 'PublicAccountability', type: :request do
  path '/api/v1/public/campaigns/{campaign_id}/accountability' do
    get 'Get campaign accountability report' do
      tags 'Public Accountability'
      produces 'application/json'
      parameter name: :campaign_id, in: :path, type: :string, format: :uuid

      response 200, 'Accountability report' do
        let(:campaign_id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end

      response 404, 'Campaign not found' do
        let(:campaign_id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end
    end
  end
end
