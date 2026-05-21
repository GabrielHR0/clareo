require "rspec/rails"

class HealthControllerTest < ActionDispatch::IntegrationTest
  describe "GET /health/cassandra" do
    it "Retorna ok se a conexão com o cassandra for bem-sucedida" do
      get cassandra_health_check_path
      assert_response :success
      assert_equal({ "status" => "ok" }, JSON.parse(response.body))
    end
  end
end
