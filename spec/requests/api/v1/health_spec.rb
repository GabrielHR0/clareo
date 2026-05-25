require 'swagger_helper'

RSpec.describe 'Health Endpoints', type: :request do
  path '/up' do
    get 'Rails Health Check' do
      tags 'Health'
      produces 'application/json'
      
      response 200, 'System is healthy' do
        example :json, :get_health_200, {
          status: 'ok'
        }
        run_test!
      end
    end
  end

  path '/health/cassandra' do
    get 'Cassandra Health Check' do
      tags 'Health'
      produces 'application/json'
      
      response 200, 'Cassandra is healthy' do
        example :json, :get_cassandra_health_200, {
          status: 'ok',
          cassandra: {
            connected: true,
            contact_points: '127.0.0.1:9042',
            keyspace: 'clareo'
          }
        }
        run_test!
      end

      response 500, 'Cassandra is not healthy' do
        example :json, :get_cassandra_health_500, {
          error: 'Cassandra connection failed',
          status: 500
        }
        run_test!
      end
    end
  end
end
