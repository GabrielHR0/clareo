require 'swagger_helper'

RSpec.describe 'Wallets', type: :request do
  path '/owners/{owner_type}/{owner_id}/wallet' do
    get 'Get wallet for owner (auto-creates if not exists)' do
      tags 'Wallets'
      parameter name: :owner_type, in: :path, schema: { type: 'string', enum: ['organization', 'contributor'] }, description: 'Owner type'
      parameter name: :owner_id, in: :path, schema: { type: 'string', format: 'uuid' }, description: 'Owner ID'
      produces 'application/json'

      response 200, 'Wallet details' do
        let(:owner_type) { 'organization' }
        let(:owner_id) { '550e8400-e29b-41d4-a716-446655440000' }
        example :json, :get_wallet_200, {
          owner_type: 'organization',
          owner_id: '550e8400-e29b-41d4-a716-446655440000',
          balance_cents: 0,
          available_cents: 0,
          locked_cents: 0,
          version: 1,
          created_at: '2026-05-25T10:30:00Z',
          updated_at: '2026-05-25T10:30:00Z'
        }
        run_test!
      end
    end
  end
end
