require 'swagger_helper'

RSpec.describe 'Contributors', type: :request do
  path '/contributors' do
    get 'List contributors' do
      tags 'Contributors'
      produces 'application/json'
      parameter name: :organization_id, in: :query, schema: { type: 'string', format: 'uuid' }, required: false,
                description: 'Filter contributors by organization (via memberships). If omitted, returns all contributors.'

      response 200, 'List of contributors' do
        example :json, :list_contributors_200, [
          {
            id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
            organization_id: '550e8400-e29b-41d4-a716-446655440000',
            email: 'john@acme.com',
            name: 'John Doe',
            created_at: '2026-05-25T10:30:00Z'
          }
        ]
        run_test!
      end
    end
  end

  path '/contributors/{id}' do
    get 'Get contributor by ID' do
      tags 'Contributors'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Contributor ID'
      produces 'application/json'

      let(:id) { SecureRandom.uuid }

      response 200, 'Contributor details' do
        example :json, :get_contributor_200, {
          id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
          organization_id: '550e8400-e29b-41d4-a716-446655440000',
          email: 'john@acme.com',
          name: 'John Doe',
          created_at: '2026-05-25T10:30:00Z'
        }
      end

      response 404, 'Contributor not found' do
        run_test!
      end
    end
  end
end
