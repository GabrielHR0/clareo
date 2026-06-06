class HealthController < ApplicationController
  def cassandra
    CassandraClient.session.execute("SELECT now() FROM system.local")
    render json: { status: "ok" }
  rescue StandardError => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def redis
    Redis.new(url: ENV["REDIS_URL"]).ping
    render json: { status: "ok" }
  rescue StandardError => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def all
    results = {
      cassandra: { status: "ok" },
      redis: { status: "ok" }
    }

    begin
      CassandraClient.session.execute("SELECT now() FROM system.local")
    rescue => e
      results[:cassandra] = { status: "error", message: e.message }
    end

    begin
      Redis.new(url: ENV["REDIS_URL"]).ping
    rescue => e
      results[:redis] = { status: "error", message: e.message }
    end

    http_status = results.values.all? { |r| r[:status] == "ok" } ? :ok : :service_unavailable
    render json: results, status: http_status
  end
end
