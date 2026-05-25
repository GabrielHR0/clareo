require "securerandom"
require "digest"
require "json"

class ProcessTransactionService
  DEFAULT_RETRIES = 3

  def self.call(owner_type:, owner_id:, amount_cents:, currency: "BRL", transaction_type: "debit", idempotency_key:, campaign_id: nil, metadata: {}, dest_owner_type: nil, dest_owner_id: nil)
    new(
      owner_type: owner_type,
      owner_id: owner_id,
      amount_cents: amount_cents.to_i,
      currency: currency,
      transaction_type: transaction_type,
      idempotency_key: idempotency_key,
      campaign_id: campaign_id,
      metadata: metadata,
      dest_owner_type: dest_owner_type,
      dest_owner_id: dest_owner_id
    ).call
  end

  def initialize(owner_type:, owner_id:, amount_cents:, currency:, transaction_type:, idempotency_key:, campaign_id:, metadata:, dest_owner_type: nil, dest_owner_id: nil)
    @owner_type = owner_type.to_s
    @owner_id = owner_id
    @amount_cents = amount_cents
    @currency = currency
    @transaction_type = transaction_type.to_s
    @idempotency_key = idempotency_key
    @campaign_id = campaign_id
    @metadata = metadata || {}
    @dest_owner_type = dest_owner_type && dest_owner_type.to_s
    @dest_owner_id = dest_owner_id
  end

  def call
    ensure_wallet_exists

    request_hash = build_request_hash
    tx_id = SecureRandom.uuid

    applied_idempotency, idempo_row = IdempotencyKeysByOwnerRepository.create_if_not_exists(
      owner_type: @owner_type,
      owner_id: @owner_id,
      idempotency_key: @idempotency_key,
      transaction_id: tx_id,
      request_hash: request_hash,
      expires_at: Time.now + 7*24*60*60
    )

    unless applied_idempotency
      # Already processed or being processed — return the recorded transaction id
      return { status: :already_processed, transaction_id: idempo_row && idempo_row[:transaction_id] }
    end

    case @transaction_type
    when "debit", "credit", "external_out", "external_in", "withdrawal"
      payment_intent_id = SecureRandom.uuid
      PaymentIntentsByOwnerRepository.insert(
        owner_type: @owner_type,
        owner_id: @owner_id,
        payment_intent_id: payment_intent_id,
        amount_cents: @amount_cents,
        campaign_id: @campaign_id,
        status: "authorized",
        provider: "fake_baas",
        provider_reference: "fake_#{payment_intent_id}",
        authorized_at: Time.now
      )

      return apply_single_wallet_flow(tx_id, payment_intent_id)

    when "transfer"
      return handle_transfer(tx_id)
    else
      raise ArgumentError, "unsupported transaction_type=#{@transaction_type}"
    end
  end

  private

  def ensure_wallet_exists
    wallet = WalletsRepository.find(@owner_id, @owner_type)
    return if wallet
    CreateWalletService.call(owner_type: @owner_type, owner_id: @owner_id)
  end

  def build_request_hash
    Digest::SHA256.hexdigest(
      JSON.generate(
        owner_type: @owner_type,
        owner_id: @owner_id.to_s,
        amount_cents: @amount_cents,
        currency: @currency,
        transaction_type: @transaction_type,
        campaign_id: @campaign_id,
        metadata: @metadata
      )
    )
  end

  def record_transaction(tx_id, payment_intent_id, status)
    TransactionsByOwnerRepository.insert(
      owner_type: @owner_type,
      owner_id: @owner_id,
      transaction_id: tx_id,
      created_at: Time.now,
      amount_cents: @amount_cents,
      currency: @currency,
      transaction_type: @transaction_type,
      status: status,
      campaign_id: @campaign_id,
      idempotency_key: @idempotency_key,
      external_reference: payment_intent_id,
      metadata: @metadata
    )
  end

  def record_ledger_entry(tx_id, balance_after)
    LedgerEntriesByOwnerRepository.insert(
      owner_type: @owner_type,
      owner_id: @owner_id,
      entry_id: SecureRandom.uuid,
      created_at: Time.now,
      transaction_id: tx_id,
      entry_type: @transaction_type == "debit" ? "debit" : "credit",
      account: "wallet",
      amount_cents: (@transaction_type == "debit" ? -@amount_cents : @amount_cents),
      balance_after_cents: balance_after,
      description: "Processed by ProcessTransactionService"
    )
  end

  # apply debit/credit/externals to a single wallet with retries
  def apply_single_wallet_flow(tx_id, payment_intent_id)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      wallet = WalletsRepository.find(@owner_id, @owner_type) || CreateWalletService.call(owner_type: @owner_type, owner_id: @owner_id)

      if ["debit", "external_out", "withdrawal"].include?(@transaction_type)
        if wallet[:available_cents].to_i < @amount_cents
          record_transaction(tx_id, payment_intent_id, "failed")
          return { status: :insufficient_funds, transaction_id: tx_id }
        end
        new_balance = wallet[:balance_cents].to_i - @amount_cents
        new_available = wallet[:available_cents].to_i - @amount_cents
        new_locked = wallet[:locked_cents].to_i
        final_status = "captured"
      else
        # credit / external_in
        new_balance = wallet[:balance_cents].to_i + @amount_cents
        new_available = wallet[:available_cents].to_i + @amount_cents
        new_locked = wallet[:locked_cents].to_i
        final_status = "captured"
      end

      applied, updated_wallet = WalletsRepository.update_balances_if_version(
        owner_id: @owner_id,
        owner_type: @owner_type,
        balance_cents: new_balance,
        available_cents: new_available,
        locked_cents: new_locked,
        expected_version: wallet[:version]
      )

      if applied
        record_transaction(tx_id, payment_intent_id, final_status)
        record_ledger_entry(tx_id, new_balance)
        # if this was a donation (credit to an organization) and metadata requests auto repayment, apply it
        repayment_info = nil
        if @transaction_type == "credit" && @owner_type == "organization"
          apply_flag = (@metadata["apply_to_credit"] || @metadata[:apply_to_credit])
          if apply_flag
            repayment_info = CreditService.apply_payment_from_donation(organization_id: @owner_id, amount_cents: @amount_cents)
          end
        end

        return { status: :ok, transaction_id: tx_id, payment_intent_id: payment_intent_id, wallet: updated_wallet, repayment: repayment_info }
      end

      sleep(0.05 * attempts)
    end

    { status: :concurrency_conflict, transaction_id: tx_id }
  end

  # transfer flow: debit source then credit destination; attempt compensation on failure
  def handle_transfer(tx_id)
    raise ArgumentError, "dest_owner_type and dest_owner_id required for transfer" unless @dest_owner_type && @dest_owner_id

    # Debit source
    applied, updated_src = attempt_debit_with_retries(tx_id)
    return { status: :insufficient_funds, transaction_id: tx_id } unless applied

    # Credit destination
    transfer_id = SecureRandom.uuid
    credited = attempt_credit_destination_with_retries(transfer_id, updated_src)
    unless credited
      # attempt to compensate source (credit back)
      compensated = compensate_source_after_failed_credit(updated_src)
      return { status: :compensated, transaction_id: tx_id } if compensated
      return { status: :compensation_failed, transaction_id: tx_id }
    end

    { status: :ok, transaction_id: tx_id, transfer_id: transfer_id }
  end

  def attempt_debit_with_retries(tx_id)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      wallet = WalletsRepository.find(@owner_id, @owner_type) || CreateWalletService.call(owner_type: @owner_type, owner_id: @owner_id)
      return [false, nil] if wallet[:available_cents].to_i < @amount_cents

      new_balance = wallet[:balance_cents].to_i - @amount_cents
      new_available = wallet[:available_cents].to_i - @amount_cents
      new_locked = wallet[:locked_cents].to_i

      applied, updated_wallet = WalletsRepository.update_balances_if_version(
        owner_id: @owner_id,
        owner_type: @owner_type,
        balance_cents: new_balance,
        available_cents: new_available,
        locked_cents: new_locked,
        expected_version: wallet[:version]
      )

      if applied
        # record source transaction and ledger
        record_transaction(tx_id, nil, "captured")
        LedgerEntriesByOwnerRepository.insert(
          owner_type: @owner_type,
          owner_id: @owner_id,
          entry_id: SecureRandom.uuid,
          created_at: Time.now,
          transaction_id: tx_id,
          entry_type: "debit",
          account: "wallet",
          amount_cents: -@amount_cents,
          balance_after_cents: updated_wallet[:balance_cents],
          description: "Transfer to #{@dest_owner_type}:#{@dest_owner_id}"
        )
        return [true, updated_wallet]
      end

      sleep(0.05 * attempts)
    end

    [false, nil]
  end

  def attempt_credit_destination_with_retries(transfer_id, source_updated_wallet)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      dest_wallet = WalletsRepository.find(@dest_owner_id, @dest_owner_type) || CreateWalletService.call(owner_type: @dest_owner_type, owner_id: @dest_owner_id)
      new_balance = dest_wallet[:balance_cents].to_i + @amount_cents
      new_available = dest_wallet[:available_cents].to_i + @amount_cents
      new_locked = dest_wallet[:locked_cents].to_i

      applied, updated_dest = WalletsRepository.update_balances_if_version(
        owner_id: @dest_owner_id,
        owner_type: @dest_owner_type,
        balance_cents: new_balance,
        available_cents: new_available,
        locked_cents: new_locked,
        expected_version: dest_wallet[:version]
      )

      if applied
        # record destination transaction and ledger
        TransactionsByOwnerRepository.insert(
          owner_type: @dest_owner_type,
          owner_id: @dest_owner_id,
          transaction_id: SecureRandom.uuid,
          created_at: Time.now,
          amount_cents: @amount_cents,
          currency: @currency,
          transaction_type: "credit",
          status: "captured",
          campaign_id: @campaign_id,
          idempotency_key: @idempotency_key,
          external_reference: "transfer_#{transfer_id}",
          metadata: @metadata
        )
        LedgerEntriesByOwnerRepository.insert(
          owner_type: @dest_owner_type,
          owner_id: @dest_owner_id,
          entry_id: SecureRandom.uuid,
          created_at: Time.now,
          transaction_id: transfer_id,
          entry_type: "credit",
          account: "wallet",
          amount_cents: @amount_cents,
          balance_after_cents: updated_dest[:balance_cents],
          description: "Transfer from #{@owner_type}:#{@owner_id}"
        )
        return true
      end

      sleep(0.05 * attempts)
    end
    false
  end

  def compensate_source_after_failed_credit(source_updated_wallet)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      src = WalletsRepository.find(@owner_id, @owner_type)
      new_balance = src[:balance_cents].to_i + @amount_cents
      new_available = src[:available_cents].to_i + @amount_cents
      new_locked = src[:locked_cents].to_i

      applied, _ = WalletsRepository.update_balances_if_version(
        owner_id: @owner_id,
        owner_type: @owner_type,
        balance_cents: new_balance,
        available_cents: new_available,
        locked_cents: new_locked,
        expected_version: src[:version]
      )

      return true if applied
      sleep(0.05 * attempts)
    end
    false
  end
end
