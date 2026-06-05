require 'swagger_helper'

RSpec.describe 'Dashboard', type: :request do
  path '/api/v1/organizations/{id}/dashboard' do
    get 'Returns organization dashboard with aggregated metrics' do
      tags 'Dashboard'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, format: :uuid

      response 200, 'Dashboard data' do
        let(:id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end

      response 404, 'Organization not found' do
        let(:id) { "00000000-0000-0000-0000-000000000000" }
        run_test!
      end
    end
  end
end
