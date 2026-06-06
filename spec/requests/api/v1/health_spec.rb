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
          status: 'ok'
        }
        run_test!
      end

      response 503, 'Cassandra is not healthy' do
        example :json, :get_cassandra_health_503, {
          status: 'error',
          message: 'Cassandra connection failed'
        }
        run_test!
      end
    end
  end

  path '/health/redis' do
    get 'Redis Health Check' do
      tags 'Health'
      produces 'application/json'

      response 200, 'Redis is healthy' do
        example :json, :get_redis_health_200, {
          status: 'ok'
        }
        run_test!
      end

      response 503, 'Redis is not healthy' do
        example :json, :get_redis_health_503, {
          status: 'error',
          message: 'Redis connection failed'
        }
        run_test!
      end
    end
  end

  path '/health/all' do
    get 'Combined Health Check' do
      tags 'Health'
      produces 'application/json'

      response 200, 'All services healthy' do
        example :json, :get_all_health_200, {
          cassandra: { status: 'ok' },
          redis: { status: 'ok' }
        }
        run_test!
      end

      response 503, 'Some service unhealthy' do
        example :json, :get_all_health_503, {
          cassandra: { status: 'ok' },
          redis: { status: 'error', message: 'Redis connection failed' }
        }
        run_test!
      end
    end
  end
end
