class SubscriptionChargeService
  def process(recurring)
    amount_cents = recurring[:amount_cents]
    owner_id = recurring[:contributor_id]
    recurring_id = recurring[:recurring_id]
    campaign_id = recurring[:campaign_id]
    org_id = recurring[:organization_id]

    idempotency_key = "recurring_#{recurring_id}_#{Date.today}"

    result = ProcessTransactionService.call(
      owner_type: "contributor",
      owner_id: owner_id,
      amount_cents: amount_cents,
      currency: "BRL",
      transaction_type: "debit",
      idempotency_key: idempotency_key,
      campaign_id: campaign_id,
      metadata: { recurring_id: recurring_id.to_s, organization_id: org_id.to_s }
    )

    if result[:status] == :ok
      { status: :ok, transaction_id: result[:transaction_id] }
    else
      { status: :failed, error: result[:error] || "wallet_debit_failed" }
    end
  end
end
