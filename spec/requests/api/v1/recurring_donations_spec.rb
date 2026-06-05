require 'swagger_helper'

RSpec.describe 'RecurringDonations', type: :request do
  let(:contrib_id) { "e05201ae-290a-48c8-8972-dbc3cd85fd90" }
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }

  path '/contributors/{contributor_id}/recurring_donations' do
    post 'Create a recurring donation' do
      tags 'Recurring Donations'
      produces 'application/json'
      consumes 'application/json'
      parameter name: :contributor_id, in: :path, type: :string, format: :uuid
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

      response 201, 'Recurring donation created' do
        let(:contributor_id) { contrib_id }
        let(:recurring_donation) { { recurring_donation: { organization_id: org_id, amount_cents: 5000, interval_days: 30, payment_method: 'wallet' } } }
        run_test!
      end
    end

    get 'List recurring donations' do
      tags 'Recurring Donations'
      produces 'application/json'
      parameter name: :contributor_id, in: :path, type: :string, format: :uuid

      response 200, 'List of recurring donations' do
        let(:contributor_id) { contrib_id }
        run_test!
      end
    end
  end
end
