require 'swagger_helper'

RSpec.describe 'Expenses', type: :request do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }
  let(:campaign_id) do
    post "/organizations/#{org_id}/campaigns", params: { campaign: { name: 'Swagger Expense', goal_cents: 100000 } }
    JSON.parse(response.body)["campaign_id"]
  end

  path '/organizations/{organization_id}/campaigns/{campaign_id}/expenses' do
    post 'Create an expense entry' do
      tags 'Expenses'
      produces 'application/json'
      consumes 'application/json'
      parameter name: :organization_id, in: :path, type: :string, format: :uuid
      parameter name: :campaign_id, in: :path, type: :string, format: :uuid
      parameter name: :expense, in: :body, schema: {
        type: :object,
        properties: {
          expense: {
            type: :object,
            properties: {
              description: { type: :string },
              amount_cents: { type: :integer },
              category: { type: :string },
              expense_date: { type: :string, format: :date }
            },
            required: [:description, :amount_cents]
          }
        }
      }

      response 201, 'Expense created' do
        let(:organization_id) { org_id }
        let(:campaign_id) { campaign_id }
        let(:expense) { { expense: { description: 'Swagger expense', amount_cents: 5000, expense_date: '2026-06-01' } } }
        run_test!
      end
    end

    get 'List expenses for a campaign' do
      tags 'Expenses'
      produces 'application/json'
      parameter name: :organization_id, in: :path, type: :string, format: :uuid
      parameter name: :campaign_id, in: :path, type: :string, format: :uuid

      response 200, 'List of expenses' do
        let(:organization_id) { org_id }
        let(:campaign_id) { campaign_id }
        run_test!
      end
    end
  end
end
