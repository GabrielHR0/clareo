require "rails_helper"

RSpec.describe "CreditLines API", type: :request do
  before(:all) do
    # ensure keyspace migrations applied in test env if needed
  end

  it "creates and uses a credit line" do
    org_id = SecureRandom.uuid
    headers = { "HOST" => "127.0.0.1" }
    post "/credit_lines", params: { credit_line: { organization_id: org_id, limit_cents: 10000 } }, as: :json, headers: headers
    expect(response).to have_http_status(:created)
    credit = JSON.parse(response.body)
    expect(credit).to include("credit_id")
    expect(credit["available_cents"]).to eq(10000)

    credit_id = credit['credit_id'].is_a?(Hash) ? credit['credit_id']['n'] : credit['credit_id']
    post "/credit_lines/#{credit_id}/use", params: { amount_cents: 2000 }, as: :json, headers: headers
    expect(response).to have_http_status(:ok)
    updated = JSON.parse(response.body)
    expect(updated["available_cents"]).to eq(8000)
  end
end
