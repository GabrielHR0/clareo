require 'swagger_helper'

RSpec.describe 'Credit Lines', type: :request do
  path '/credit_lines' do
    get 'List all credit lines' do
      tags 'Credit Lines'
      produces 'application/json'
      
      response 200, 'List of credit lines' do
        example :json, :list_credit_lines_200, [
          {
            credit_line_id: '6e9bc30-1f1f-597f-1f1f-8b1f7b0c0c11',
            owner_type: 'organization',
            owner_id: '550e8400-e29b-41d4-a716-446655440000',
            limit_cents: 1000000,
            available_cents: 750000,
            created_at: '2026-05-25T10:30:00Z'
          }
        ]
        run_test!
      end
    end

    post 'Create a credit line' do
      tags 'Credit Lines'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :credit_line, in: :body, schema: {
        type: 'object',
        properties: {
          owner_type: { type: 'string', enum: ['organization', 'contributor'], description: 'Owner type' },
          owner_id: { type: 'string', format: 'uuid', description: 'Owner ID' },
          limit_cents: { type: 'integer', description: 'Credit limit in cents' }
        },
        required: ['owner_type', 'owner_id', 'limit_cents']
      }, description: 'Credit line payload'
      
      response 201, 'Credit line created' do
        example :json, :create_credit_line_201, {
          credit_line_id: '6e9bc30-1f1f-597f-1f1f-8b1f7b0c0c11',
          owner_type: 'organization',
          owner_id: '550e8400-e29b-41d4-a716-446655440000',
          limit_cents: 1000000,
          available_cents: 1000000,
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Invalid parameters' do
        example :json, :create_credit_line_400, {
          error: 'Limit cents is required'
        }
        run_test!
      end
    end
  end

  path '/credit_lines/{id}' do
    get 'Get credit line by ID' do
      tags 'Credit Lines'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Credit line ID'
      produces 'application/json'
      
      response 200, 'Credit line details' do
        example :json, :get_credit_line_200, {
          credit_line_id: '6e9bc30-1f1f-597f-1f1f-8b1f7b0c0c11',
          owner_type: 'organization',
          owner_id: '550e8400-e29b-41d4-a716-446655440000',
          limit_cents: 1000000,
          available_cents: 750000,
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 404, 'Credit line not found' do
        example :json, :get_credit_line_404, {
          error: 'Credit line not found'
        }
        run_test!
      end
    end
  end

  path '/credit_lines/{id}/use' do
    post 'Use credit line (draw on available credit)' do
      tags 'Credit Lines'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Credit line ID'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :usage, in: :body, schema: {
        type: 'object',
        properties: {
          amount_cents: { type: 'integer', description: 'Amount to draw in cents' },
          reference: { type: 'string', nullable: true, description: 'Reference for this draw (optional)' }
        },
        required: ['amount_cents']
      }, description: 'Credit usage payload'
      
      response 200, 'Credit drawn successfully' do
        example :json, :use_credit_line_200, {
          credit_line_id: '6e9bc30-1f1f-597f-1f1f-8b1f7b0c0c11',
          available_cents: 650000,
          amount_drawn_cents: 100000,
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Insufficient available credit' do
        example :json, :use_credit_line_400, {
          error: 'Insufficient available credit',
          available_cents: 100000,
          requested_cents: 200000
        }
        run_test!
      end

      response 404, 'Credit line not found' do
        example :json, :use_credit_line_404, {
          error: 'Credit line not found'
        }
        run_test!
      end
    end
  end
end
