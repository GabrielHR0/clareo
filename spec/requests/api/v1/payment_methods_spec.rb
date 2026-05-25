require 'swagger_helper'

RSpec.describe 'Payment Methods', type: :request do
  path '/owners/{owner_type}/{owner_id}/payment_methods' do
    post 'Create a payment method' do
      tags 'Payment Methods'
      parameter name: :owner_type, in: :path, schema: { type: 'string', enum: ['organization', 'contributor'] }, description: 'Owner type'
      parameter name: :owner_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Owner ID'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :payment_method, in: :body, schema: {
        type: 'object',
        properties: {
          payment_type: { 
            type: 'string', 
            enum: ['credit_card', 'bank_transfer', 'pix'],
            description: 'Type of payment method'
          },
          reference: { type: 'string', description: 'Payment method reference (card token, account number, PIX key, etc.)' },
          is_default: { type: 'boolean', default: false, description: 'Mark as default payment method' }
        },
        required: ['payment_type', 'reference']
      }, description: 'Payment method payload'
      
      response 201, 'Payment method created' do
        example :json, :create_payment_method_201, {
          payment_method_id: '5d8ac20-1f1f-597f-1f1f-8b1f7b0c0c10',
          owner_type: 'organization',
          owner_id: '550e8400-e29b-41d4-a716-446655440000',
          payment_type: 'credit_card',
          reference: 'tok_visa_4242',
          is_default: true,
          created_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end

      response 400, 'Invalid payment type' do
        example :json, :create_payment_method_400, {
          error: 'Payment type is invalid'
        }
        run_test!
      end
    end
  end
end
