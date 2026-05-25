require "rails_helper"

RSpec.describe "Credit auto repayment", type: :request do
  it "applies a donation to open credit lines when requested" do
    org_id = SecureRandom.uuid

    post "/credit_lines", params: { credit_line: { organization_id: org_id, limit_cents: 5000 } }, as: :json, headers: { "HOST" => "127.0.0.1" }
    expect(response).to have_http_status(:created)
    credit = JSON.parse(response.body)
    credit_id = credit["credit_id"]

    post "/credit_lines/#{credit_id}/use", params: { amount_cents: 2000 }, as: :json, headers: { "HOST" => "127.0.0.1" }
    expect(response).to have_http_status(:ok)

    result = CreditService.apply_payment_from_donation(organization_id: org_id, amount_cents: 1500)
    expect(result[:status]).to eq(:applied)
    expect(result[:remaining]).to eq(0)

    updated = CreditLinesRepository.find(credit_id)
    expect(updated[:used_cents]).to eq(500)
    expect(updated[:available_cents]).to eq(4500)
  end
end
