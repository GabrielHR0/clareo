require "securerandom"

class CreditService
  DEFAULT_RETRIES = 3

  def self.create_line(organization_id:, limit_cents:, annual_rate: nil)
    applied, credit = CreditLinesRepository.create_if_not_exists(
      organization_id: organization_id,
      limit_cents: limit_cents,
      used_cents: 0,
      available_cents: limit_cents,
      annual_rate: annual_rate,
      status: "active"
    )
    credit
  end

  # attempt to use credit; returns { status: :ok, credit: } or { status: :insufficient } or { status: :conflict }
  def self.use_credit(credit_id:, amount_cents:)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      credit = CreditLinesRepository.find(credit_id)
      return { status: :not_found } unless credit

      if credit[:available_cents].to_i < amount_cents
        return { status: :insufficient, credit: credit }
      end

      expected_used = credit[:used_cents].to_i
      new_used = expected_used + amount_cents
      new_available = credit[:available_cents].to_i - amount_cents

      applied, updated = CreditLinesRepository.update_used_if_expected(
        credit_id: credit[:credit_id],
        expected_used: expected_used,
        new_used: new_used,
        new_available: new_available
      )

      if applied
        # record a debt transaction + ledger entry for the organization
        TransactionsByOwnerRepository.insert(
          owner_type: "organization",
          owner_id: credit[:organization_id],
          transaction_id: SecureRandom.uuid,
          created_at: Time.now,
          amount_cents: amount_cents,
          currency: "BRL",
          transaction_type: "credit_line_draw",
          status: "captured",
          campaign_id: nil,
          idempotency_key: nil,
          external_reference: "credit_draw_#{credit[:credit_id]}",
          metadata: { "credit_id" => credit[:credit_id].to_s }
        )

        LedgerEntriesByOwnerRepository.insert(
          owner_type: "organization",
          owner_id: credit[:organization_id],
          entry_id: SecureRandom.uuid,
          created_at: Time.now,
          transaction_id: nil,
          entry_type: "debit",
          account: "credit_line",
          amount_cents: -amount_cents,
          balance_after_cents: updated[:available_cents],
          description: "Credit draw #{credit[:credit_id]}"
        )

        # emit kafka event
        KafkaProducer.publish("credit.line_used", { credit_id: credit[:credit_id], organization_id: credit[:organization_id], amount_cents: amount_cents, timestamp: Time.now })

        return { status: :ok, credit: updated }
      end

      sleep(0.02 * attempts)
    end

    { status: :conflict }
  end

  # repay a credit line by id
  def self.repay_credit(credit_id:, amount_cents:)
    attempts = 0
    while attempts < DEFAULT_RETRIES
      attempts += 1
      credit = CreditLinesRepository.find(credit_id)
      return { status: :not_found } unless credit

      expected_used = credit[:used_cents].to_i
      repay_amount = [amount_cents, expected_used].min
      return { status: :nothing_to_repay } if repay_amount <= 0

      new_used = expected_used - repay_amount
      new_available = credit[:available_cents].to_i + repay_amount

      applied, updated = CreditLinesRepository.update_used_if_expected(
        credit_id: credit[:credit_id],
        expected_used: expected_used,
        new_used: new_used,
        new_available: new_available
      )

      if applied
        # record repayment transaction and ledger entry
        TransactionsByOwnerRepository.insert(
          owner_type: "organization",
          owner_id: credit[:organization_id],
          transaction_id: SecureRandom.uuid,
          created_at: Time.now,
          amount_cents: repay_amount,
          currency: "BRL",
          transaction_type: "credit_repayment",
          status: "captured",
          campaign_id: nil,
          idempotency_key: nil,
          external_reference: "credit_repay_#{credit[:credit_id]}",
          metadata: { "credit_id" => credit[:credit_id].to_s }
        )

        LedgerEntriesByOwnerRepository.insert(
          owner_type: "organization",
          owner_id: credit[:organization_id],
          entry_id: SecureRandom.uuid,
          created_at: Time.now,
          transaction_id: nil,
          entry_type: "credit",
          account: "credit_line",
          amount_cents: repay_amount,
          balance_after_cents: updated[:available_cents],
          description: "Repayment for #{credit[:credit_id]}"
        )

        KafkaProducer.publish("credit.repayment", { credit_id: credit[:credit_id], organization_id: credit[:organization_id], amount_cents: repay_amount, timestamp: Time.now })

        return { status: :ok, credit: updated }
      end

      sleep(0.02 * attempts)
    end

    { status: :conflict }
  end

  # Apply payment (e.g., donation) toward org's credit lines (oldest first)
  def self.apply_payment_from_donation(organization_id:, amount_cents:)
    remaining = amount_cents
    credits = CreditLinesRepository.find_by_organization(organization_id)
    # sort by created_at ascending (oldest debts first)
    credits = credits.sort_by { |c| c[:created_at].to_time rescue Time.at(0) }

    credits.each do |credit|
      break if remaining <= 0
      used = credit[:used_cents].to_i
      next if used <= 0
      pay = [used, remaining].min
      res = repay_credit(credit_id: credit[:credit_id], amount_cents: pay)
      if res[:status] == :ok
        remaining -= pay
      else
        # on conflict, try next credit line
        next
      end
    end

    { status: :applied, remaining: remaining }
  end
end
