require 'swagger_helper'

RSpec.describe 'PublicAccountability', type: :request do
  path '/api/v1/public/campaigns/{campaign_id}/accountability' do
    get 'Get campaign accountability report' do
      tags 'Public Accountability'
      produces 'application/json'
      parameter name: :campaign_id, in: :path, type: :string, format: :uuid

      response 200, 'Accountability report' do
        let(:org_id) { SecureRandom.uuid }
        let(:campaign_id) { SecureRandom.uuid }

        before do
          OrganizationsRepository.create(organization_id: org_id, name: 'Test Org')
          CampaignService.create(organization_id: org_id, campaign_id: campaign_id, name: 'Test Campaign', goal_cents: 100000)
        end

        run_test!
      end

      response 404, 'Campaign not found' do
        let(:campaign_id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end
    end
  end
end
