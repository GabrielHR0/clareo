require 'swagger_helper'

RSpec.describe 'Memberships', type: :request do
  path '/memberships' do
    get 'List all memberships' do
      tags 'Memberships'
      produces 'application/json'
      
      response 200, 'List of memberships' do
        example :json, :list_memberships_200, [
          {
            id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
            organization_id: '550e8400-e29b-41d4-a716-446655440000',
            contributor_id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
            role: 'admin',
            created_at: '2026-05-25T10:30:00Z'
          }
        ]
        run_test!
      end
    end

    post 'Create a new membership' do
      tags 'Memberships'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :membership, in: :body, schema: {
        type: 'object',
        properties: {
          organization_id: { type: 'string', format: 'uuid', description: 'Organization ID' },
          contributor_id: { type: 'string', format: 'uuid', description: 'Contributor ID' },
          role: { type: 'string', enum: ['admin', 'user'], description: 'Membership role' }
        },
        required: ['organization_id', 'contributor_id', 'role']
      }, description: 'Membership payload'
      
      response 201, 'Membership created' do
        example :json, :create_membership_201, {
          id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
          organization_id: '550e8400-e29b-41d4-a716-446655440000',
          contributor_id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
          role: 'admin',
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Invalid parameters' do
        example :json, :create_membership_400, {
          error: 'Role is required'
        }
        run_test!
      end
    end
  end
end
