require 'swagger_helper'

RSpec.describe 'Associations', type: :request do
  path '/api/v1/associations' do
    get 'List user associations' do
      tags 'Associations'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      response '200', 'List of associated organizations' do
        security [{ BearerAuth: [] }]
        example :json, :list_associations_200, [
          {
            organization_id: '550e8400-e29b-41d4-a716-446655440000',
            contributor_id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
            membership_id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
            status: 'active',
            organization_name: 'Instituição Exemplo',
            organization_status: 'active',
            campaigns_count: 2,
            campaigns: [
              { campaign_id: '8b68bd20-2f2f-608f-2f2f-9c2f8b1d0d0e', name: 'Campanha 1', status: 'active' }
            ]
          }
        ]
      end

      response '401', 'Unauthorized' do
        security [{ BearerAuth: [] }]
        example :json, :list_associations_401, {
          error: 'Invalid or expired token'
        }
      end
    end

    post 'Associate with an organization' do
      tags 'Associations'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          organization_id: { type: :string, format: :uuid, description: 'Organization ID to associate with' }
        },
        required: ['organization_id']
      }, description: 'Association payload'

      response '201', 'Association created' do
        security [{ BearerAuth: [] }]
        example :json, :create_association_201, {
          membership_id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
          organization_id: '550e8400-e29b-41d4-a716-446655440000'
        }
      end

      response '422', 'Invalid parameters' do
        security [{ BearerAuth: [] }]
        example :json, :create_association_422, {
          error: 'organization_id required'
        }
      end

      response '409', 'Already associated' do
        security [{ BearerAuth: [] }]
        example :json, :create_association_409, {
          error: 'Already associated with this organization'
        }
      end
    end
  end

  path '/api/v1/associations/{organization_id}' do
    delete 'Remove association with an organization' do
      tags 'Associations'
      security [{ BearerAuth: [] }]
      parameter name: :organization_id, in: :path, type: :string, format: :uuid, description: 'Organization ID'

      response '204', 'Association removed' do
        security [{ BearerAuth: [] }]
      end

      response '422', 'Invalid parameters' do
        security [{ BearerAuth: [] }]
        example :json, :delete_association_422, {
          error: 'organization_id required'
        }
      end
    end
  end
end
