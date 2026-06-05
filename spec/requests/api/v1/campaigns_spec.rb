require 'swagger_helper'

RSpec.describe 'Campaigns', type: :request do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }

  path '/organizations/{organization_id}/campaigns' do
    post 'Create a campaign' do
      tags 'Campaigns'
      produces 'application/json'
      consumes 'application/json'
      parameter name: :organization_id, in: :path, type: :string, format: :uuid
      parameter name: :campaign, in: :body, schema: {
        type: :object,
        properties: {
          campaign: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              goal_cents: { type: :integer }
            },
            required: [:name, :goal_cents]
          }
        }
      }

      response 201, 'Campaign created' do
        let(:organization_id) { org_id }
        let(:campaign) { { campaign: { name: 'Swagger Campaign', goal_cents: 100000 } } }
        run_test!
      end
    end

    get 'List campaigns' do
      tags 'Campaigns'
      produces 'application/json'
      parameter name: :organization_id, in: :path, type: :string, format: :uuid

      response 200, 'List of campaigns' do
        let(:organization_id) { org_id }
        run_test!
      end
    end
  end

  path '/organizations/{organization_id}/campaigns/{id}' do
    get 'Show campaign' do
      tags 'Campaigns'
      produces 'application/json'
      parameter name: :organization_id, in: :path, type: :string, format: :uuid
      parameter name: :id, in: :path, type: :string, format: :uuid

      response 200, 'Campaign details' do
        let(:organization_id) { org_id }
        let(:id) do
          post "/organizations/#{org_id}/campaigns", params: { campaign: { name: 'Swagger Show', goal_cents: 100000 } }
          JSON.parse(response.body)["campaign_id"]
        end
        run_test!
      end
    end
  end
end
