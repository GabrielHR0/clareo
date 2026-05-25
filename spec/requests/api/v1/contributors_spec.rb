require 'swagger_helper'

RSpec.describe 'Contributors', type: :request do
  path '/contributors' do
    get 'List all contributors' do
      tags 'Contributors'
      produces 'application/json'
      
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

    post 'Create a new contributor' do
      tags 'Contributors'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :contributor, in: :body, schema: {
        type: 'object',
        properties: {
          organization_id: { type: 'string', format: 'uuid', description: 'Organization ID' },
          email: { type: 'string', format: 'email', description: 'Contributor email' },
          name: { type: 'string', description: 'Contributor name' }
        },
        required: ['organization_id', 'email', 'name']
      }, description: 'Contributor payload'
      
      response 201, 'Contributor created' do
        example :json, :create_contributor_201, {
          id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
          organization_id: '550e8400-e29b-41d4-a716-446655440000',
          email: 'john@acme.com',
          name: 'John Doe',
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Invalid parameters' do
        example :json, :create_contributor_400, {
          error: 'Email is required'
        }
        run_test!
      end
    end
  end

  path '/contributors/{id}' do
    get 'Get contributor by ID' do
      tags 'Contributors'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Contributor ID'
      produces 'application/json'
      
      response 200, 'Contributor details' do
        example :json, :get_contributor_200, {
          id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
          organization_id: '550e8400-e29b-41d4-a716-446655440000',
          email: 'john@acme.com',
          name: 'John Doe',
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 404, 'Contributor not found' do
        example :json, :get_contributor_404, {
          error: 'Contributor not found'
        }
        run_test!
      end
    end
  end
end
