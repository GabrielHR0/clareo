require 'swagger_helper'

RSpec.describe 'Transactions', type: :request do
  path '/owners/{owner_type}/{owner_id}/transactions' do
    post 'Create a transaction' do
      tags 'Transactions'
      parameter name: :owner_type, in: :path, schema: { type: 'string', enum: ['organization', 'contributor'] }, description: 'Owner type'
      parameter name: :owner_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Owner ID'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :transaction, in: :body, schema: {
        type: 'object',
        properties: {
          amount_cents: { type: 'integer', description: 'Amount in cents (e.g., 10000 = 100.00 BRL)' },
          currency: { type: 'string', default: 'BRL', description: 'Currency code' },
          transaction_type: { 
            type: 'string', 
            enum: ['credit', 'debit', 'transfer', 'external_in', 'external_out', 'withdrawal'],
            description: 'Type of transaction'
          },
          idempotency_key: { type: 'string', description: 'Unique key for idempotency' },
          campaign_id: { type: 'string', format: 'uuid', nullable: true, description: 'Associated campaign ID (optional)' },
          metadata: { type: 'object', nullable: true, description: 'Additional metadata (optional)' },
          dest_owner_type: { 
            type: 'string', 
            enum: ['organization', 'contributor'],
            nullable: true,
            description: 'Destination owner type (required for transfer)' 
          },
          dest_owner_id: { 
            type: 'string', 
            format: 'uuid',
            nullable: true,
            description: 'Destination owner ID (required for transfer)' 
          }
        },
        required: ['amount_cents', 'transaction_type', 'idempotency_key']
      }, description: 'Transaction payload'
      
      response 201, 'Transaction created (credit)' do
        example :json, :create_transaction_credit_201, {
          status: 'ok',
          transaction_id: '8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e',
          provider_reference: 'fake_b9c57887-ab58-461c-bbf0-688bc9125eb4'
        }
        run_test!
      end

      response 201, 'Transaction created (transfer)' do
        example :json, :create_transaction_transfer_201, {
          status: 'ok',
          transaction_id: 'bc5749b8-b074-4da1-86ea-b55779ab2b7c',
          transfer_id: '5a4bc0e3-2b36-4a7d-afda-537e544457e9',
          provider_reference: 'fake_transfer_47a2fb4d-9bf5-4b20-a162-d74bb78c400f'
        }
        run_test!
      end

      response 200, 'Transaction already processed (idempotency)' do
        example :json, :create_transaction_idempotent_200, {
          status: 'already_processed',
          transaction_id: 'bc5749b8-b074-4da1-86ea-b55779ab2b7c'
        }
        run_test!
      end

      response 400, 'Insufficient funds' do
        example :json, :create_transaction_insufficient_400, {
          status: 'insufficient_funds',
          transaction_id: 'e85c9e4f-db02-4ed6-9a30-91fa367ee159'
        }
        run_test!
      end

      response 400, 'Invalid transaction type' do
        example :json, :create_transaction_invalid_400, {
          error: 'Invalid transaction_type'
        }
        run_test!
      end
    end

    get 'List transactions for owner' do
      tags 'Transactions'
      parameter name: :owner_type, in: :path, schema: { type: 'string', enum: ['organization', 'contributor'] }, description: 'Owner type'
      parameter name: :owner_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Owner ID'
      parameter name: :limit, in: :query, schema: { type: 'integer', default: 100 }, description: 'Maximum number of results'
      produces 'application/json'
      
      response 200, 'List of transactions' do
        example :json, :list_transactions_200, [
          {
            owner_type: 'organization',
            owner_id: '550e8400-e29b-41d4-a716-446655440000',
            transaction_id: '8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e',
            created_at: '2026-05-25T14:30:00Z',
            amount_cents: 100000,
            currency: 'BRL',
            transaction_type: 'credit',
            status: 'captured',
            campaign_id: nil,
            idempotency_key: 'demo1-550e8400-e29b-41d4-a716-446655440000',
            external_reference: 'fake_b9c57887-ab58-461c-bbf0-688bc9125eb4',
            metadata: nil
          },
          {
            owner_type: 'organization',
            owner_id: '550e8400-e29b-41d4-a716-446655440000',
            transaction_id: 'bc5749b8-b074-4da1-86ea-b55779ab2b7c',
            created_at: '2026-05-25T14:45:00Z',
            amount_cents: 10000,
            currency: 'BRL',
            transaction_type: 'transfer',
            status: 'captured',
            campaign_id: nil,
            idempotency_key: 'transfer-1779735867636180555',
            external_reference: 'fake_transfer_47a2fb4d-9bf5-4b20-a162-d74bb78c400f',
            metadata: nil
          }
        ]
        run_test!
      end
    end
  end

  path '/owners/{owner_type}/{owner_id}/transactions/{id}' do
    get 'Get transaction details' do
      tags 'Transactions'
      parameter name: :owner_type, in: :path, schema: { type: 'string', enum: ['organization', 'contributor'] }, description: 'Owner type'
      parameter name: :owner_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Owner ID'
      parameter name: :id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Transaction ID'
      produces 'application/json'
      
      response 200, 'Transaction details' do
        example :json, :get_transaction_200, {
          owner_type: 'organization',
          owner_id: '550e8400-e29b-41d4-a716-446655440000',
          transaction_id: '8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e',
          created_at: '2026-05-25T14:30:00Z',
          amount_cents: 100000,
          currency: 'BRL',
          transaction_type: 'credit',
          status: 'captured',
          campaign_id: nil,
          idempotency_key: 'demo1-550e8400-e29b-41d4-a716-446655440000',
          external_reference: 'fake_b9c57887-ab58-461c-bbf0-688bc9125eb4',
          metadata: nil
        }
        run_test!
      end

      response 404, 'Transaction not found' do
        example :json, :get_transaction_404, {
          error: 'Transaction not found'
        }
        run_test!
      end
    end
  end

  path '/campaigns/{campaign_id}/transactions' do
    get 'List transactions for campaign' do
      tags 'Transactions'
      parameter name: :campaign_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Campaign ID'
      parameter name: :limit, in: :query, schema: { type: 'integer', default: 100 }, description: 'Maximum number of results'
      produces 'application/json'
      
      response 200, 'List of campaign transactions' do
        example :json, :list_campaign_transactions_200, [
          {
            campaign_id: '9c7ac20-1f1f-597f-1f1f-8b1f7b0c0c0f',
            transaction_id: '8b69bd10-1f1f-597f-1f1f-8b1f7b0c0c0e',
            created_at: '2026-05-25T14:30:00Z',
            owner_type: 'organization',
            owner_id: '550e8400-e29b-41d4-a716-446655440000',
            amount_cents: 50000,
            currency: 'BRL',
            transaction_type: 'credit',
            status: 'captured',
            idempotency_key: 'campaign1-demo-'550e8400-e29b-41d4-a716-446655440000',
            external_reference: 'fake_b9c57887-ab58-461c-bbf0-688bc9125eb4',
            metadata: nil
          }
        ]
        run_test!
      end
    end
  end
end
