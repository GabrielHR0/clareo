require 'swagger_helper'

RSpec.describe 'MyRecurringDonations', type: :request do
  path '/api/v1/me/recurring_donations' do
    get 'List my recurring donations' do
      tags 'My Recurring Donations'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      response '200', 'List of recurring donations' do
        security [{ BearerAuth: [] }]
        example :json, :list_my_recurring_200, [
          {
            organization_id: '550e8400-e29b-41d4-a716-446655440000',
            contributor_id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c',
            recurring_id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
            amount_cents: 5000,
            currency: 'BRL',
            payment_method: 'card',
            interval_days: 30,
            next_charge_date: '2026-07-08',
            status: 'active',
            organization_name: 'Instituição Exemplo'
          }
        ]
      end

      response '401', 'Unauthorized' do
        security [{ BearerAuth: [] }]
        example :json, :list_my_recurring_401, {
          error: 'Invalid or expired token'
        }
      end
    end

    post 'Create a recurring donation' do
      tags 'My Recurring Donations'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :recurring_donation, in: :body, schema: {
        type: :object,
        properties: {
          recurring_donation: {
            type: :object,
            properties: {
              organization_id: { type: :string, format: :uuid },
              amount_cents: { type: :integer },
              interval_days: { type: :integer },
              payment_method: { type: :string }
            },
            required: [:organization_id, :amount_cents]
          }
        }
      }

      response '201', 'Recurring donation created' do
        security [{ BearerAuth: [] }]
        example :json, :create_my_recurring_201, {
          recurring_id: '7a58ac10-1f1f-597f-1f1f-8b1f7b0c0c0d',
          organization_id: '550e8400-e29b-41d4-a716-446655440000',
          contributor_id: '6f47ac10-1f1f-597f-1f1f-8b1f7b0c0c0c'
        }
      end

      response '422', 'Invalid parameters' do
        security [{ BearerAuth: [] }]
        example :json, :create_my_recurring_422, {
          error: 'organization_id is required'
        }
      end
    end
  end

  path '/api/v1/me/recurring_donations/{id}' do
    delete 'Cancel a recurring donation' do
      tags 'My Recurring Donations'
      security [{ BearerAuth: [] }]
      parameter name: :id, in: :path, type: :string, format: :uuid
      parameter name: :organization_id, in: :query, type: :string, format: :uuid, required: true

      response '200', 'Recurring donation cancelled' do
        security [{ BearerAuth: [] }]
      end

      response '404', 'Recurring donation not found' do
        security [{ BearerAuth: [] }]
        example :json, :delete_my_recurring_404, {
          error: 'Not found'
        }
      end
    end
  end
end
