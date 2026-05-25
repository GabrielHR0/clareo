class SubscriptionChargeService
  def initialize(repos: {})
    @wallets_repo = repos[:wallets] || WalletsRepository.new
    @transactions_repo = repos[:transactions] || TransactionsByOwnerRepository.new
    @payment_intents_repo = repos[:payment_intents] || PaymentIntentsByOwnerRepository.new
    @payment_methods_repo = repos[:payment_methods] || PaymentMethodsRepository.new
  end

  # Process a single recurring donation record.
  # Tries to debit contributor's wallet; if insufficient, falls back to card charge.
  def process(recurring)
    tx_id = SecureRandom.uuid
    amount_cents = recurring[:amount_cents]
    owner_type = 'contributor'
    owner_id = recurring[:contributor_id]

    payment_intent_id = SecureRandom.uuid
    @payment_intents_repo.insert(
      owner_type: owner_type,
      owner_id: owner_id,
      amount_cents: amount_cents,
      status: 'created',
      provider: 'internal',
      payment_intent_id: payment_intent_id
    )

    # Attempt wallet debit via existing ProcessTransactionService flow
    pts = ProcessTransactionService.new
    result = pts.process({
      owner_type: owner_type,
      owner_id: owner_id,
      amount_cents: amount_cents,
      kind: 'donation',
      metadata: { recurring_id: recurring[:recurring_id].to_s }
    })

    if result[:status] == :ok
      { status: :ok, method: :wallet, transaction_id: result[:transaction_id], payment_intent_id: result[:payment_intent_id] }
    else
      # Determine payment method: prefer recurring-specified, else owner's default
      payment_method = recurring[:payment_method]
      card_ref = recurring[:card_reference]
      if payment_method.to_s.strip.empty?
        default = @payment_methods_repo.find_default(owner_type, owner_id)
        if default && default[:method_type] == 'card'
          payment_method = 'card'
          card_ref = default[:details]['card_reference']
        end
      end

      # Fallback to card when wallet debit failed and a card is available
      charge = PaymentGateway.charge_card(card_reference: card_ref, amount_cents: amount_cents)
      if charge[:success]
        # record transaction as card capture
        @transactions_repo.insert(
          owner_type: owner_type,
          owner_id: owner_id,
          transaction_id: tx_id,
          amount_cents: amount_cents,
          kind: 'donation',
          external_reference: charge[:reference]
        )
        @payment_intents_repo.insert(
          owner_type: owner_type,
          owner_id: owner_id,
          amount_cents: amount_cents,
          status: 'succeeded',
          provider: 'card',
          provider_reference: charge[:reference],
          payment_intent_id: payment_intent_id
        )
        { status: :ok, method: :card, transaction_id: tx_id, payment_intent_id: payment_intent_id }
      else
        @payment_intents_repo.insert(
          owner_type: owner_type,
          owner_id: owner_id,
          amount_cents: amount_cents,
          status: 'failed',
          provider: 'card',
          failed_reason: charge[:error],
          payment_intent_id: payment_intent_id
        )
        { status: :failed, error: charge[:error] }
      end
    end
  end
end
