class HealthController < ApplicationController
  def cassandra
    CassandraClient.session.execute("SELECT now() FROM system.local")
    render json: { status: "ok" }
  rescue StandardError => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end
end
