require 'swagger_helper'

RSpec.describe 'Organizations', type: :request do
  path '/organizations' do
    get 'List all organizations' do
      tags 'Organizations'
      produces 'application/json'
      
      response 200, 'List of organizations' do
        example :json, :list_organizations_200, [
          {
            id: '550e8400-e29b-41d4-a716-446655440000',
            name: 'Acme Corporation',
            external_id: 'ext_123',
            created_at: '2026-05-25T10:30:00Z'
          },
          {
            id: '550e8400-e29b-41d4-a716-446655440001',
            name: 'Tech Startup Inc',
            external_id: nil,
            created_at: '2026-05-25T11:45:00Z'
          }
        ]
        run_test!
      end
    end

    post 'Create a new organization' do
      tags 'Organizations'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :organization, in: :body, schema: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Organization name' },
          external_id: { type: 'string', description: 'External identifier (optional)' }
        },
        required: ['name']
      }, description: 'Organization payload'
      
      response 201, 'Organization created' do
        example :json, :create_organization_201, {
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: 'Acme Corporation',
          external_id: 'ext_123',
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Invalid parameters' do
        example :json, :create_organization_400, {
          error: 'Name is required'
        }
        run_test!
      end
    end
  end

  path '/organizations/{id}' do
    get 'Get organization by ID' do
      tags 'Organizations'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Organization ID'
      produces 'application/json'
      
      response 200, 'Organization details' do
        example :json, :get_organization_200, {
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: 'Acme Corporation',
          external_id: 'ext_123',
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 404, 'Organization not found' do
        example :json, :get_organization_404, {
          error: 'Organization not found'
        }
        run_test!
      end
    end
  end
end
