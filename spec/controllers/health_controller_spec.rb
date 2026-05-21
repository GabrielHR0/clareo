require "rails_helper"

RSpec.describe "Health", type: :request do
  describe "GET /health/cassandra" do
    it "retorna ok quando Cassandra responde" do
      get cassandra_health_check_path

      test_log_json("playload", { ok: true }, level: :info)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "status" => "ok" })
    end
  end
end
