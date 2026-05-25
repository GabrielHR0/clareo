require "securerandom"

module FakeBaasGateway
  extend self

  # In-memory store for simulating SaaS state (for demo; in production, use a real external service)
  @@transactions = {}
  @@holds = {}

  # Simulate authorization and return provider reference
  def authorize(amount_cents:, currency:, owner_type:, owner_id:, metadata: {})
    # Simulate authorization via external gateway
    ref = "fake_auth_#{SecureRandom.uuid}"
    txn = {
      id: ref,
      owner_type: owner_type.to_s,
      owner_id: owner_id.to_s,
      amount_cents: amount_cents,
      currency: currency,
      status: 'authorized',
      metadata: metadata,
      authorized_at: Time.now,
      created_at: Time.now
    }
    @@transactions[ref] = txn

    {
      status: 'authorized',
      provider: 'fake_baas',
      provider_reference: ref,
      authorized_at: Time.now,
      transaction_id: ref
    }
  end

  def capture(provider_reference:)
    txn = @@transactions[provider_reference]
    return { status: 'error', error: 'transaction_not_found' } unless txn

    txn[:status] = 'captured'
    txn[:captured_at] = Time.now

    {
      status: 'captured',
      provider_reference: provider_reference,
      captured_at: Time.now,
      transaction_id: provider_reference
    }
  end

  def refund(provider_reference:, amount_cents:)
    txn = @@transactions[provider_reference]
    return { status: 'error', error: 'transaction_not_found' } unless txn
    return { status: 'error', error: 'already_refunded' } if txn[:status] == 'refunded'

    txn[:status] = 'refunded'
    txn[:refunded_at] = Time.now

    {
      status: 'refunded',
      provider_reference: provider_reference,
      refunded_at: Time.now,
      transaction_id: provider_reference
    }
  end

  # Hold funds temporarily (for multi-step flows like transfers)
  def hold(amount_cents:, currency:, owner_type:, owner_id:, metadata: {})
    ref = "fake_hold_#{SecureRandom.uuid}"
    hold_record = {
      id: ref,
      owner_type: owner_type.to_s,
      owner_id: owner_id.to_s,
      amount_cents: amount_cents,
      currency: currency,
      status: 'held',
      metadata: metadata,
      held_at: Time.now,
      created_at: Time.now
    }
    @@holds[ref] = hold_record

    {
      status: 'held',
      provider: 'fake_baas',
      provider_reference: ref,
      held_at: Time.now,
      hold_id: ref
    }
  end

  # Release held funds
  def release_hold(hold_reference:)
    hold = @@holds[hold_reference]
    return { status: 'error', error: 'hold_not_found' } unless hold

    hold[:status] = 'released'
    hold[:released_at] = Time.now

    {
      status: 'released',
      provider_reference: hold_reference,
      released_at: Time.now
    }
  end

  # Complete a transfer: debit source, credit destination atomically (from gateway perspective)
  def transfer(
    amount_cents:,
    currency:,
    source_owner_type:,
    source_owner_id:,
    dest_owner_type:,
    dest_owner_id:,
    metadata: {}
  )
    # In a real SaaS, this would be a single atomic operation on the gateway
    # For the fake gateway, we simulate it as two linked authorizations
    source_hold_ref = "fake_hold_src_#{SecureRandom.uuid}"
    transfer_ref = "fake_transfer_#{SecureRandom.uuid}"

    source_hold = {
      id: source_hold_ref,
      owner_type: source_owner_type.to_s,
      owner_id: source_owner_id.to_s,
      amount_cents: amount_cents,
      currency: currency,
      status: 'held_for_transfer',
      transfer_id: transfer_ref,
      metadata: metadata,
      held_at: Time.now
    }
    @@holds[source_hold_ref] = source_hold

    transfer_txn = {
      id: transfer_ref,
      transfer_type: 'p2p_transfer',
      source_owner_type: source_owner_type.to_s,
      source_owner_id: source_owner_id.to_s,
      dest_owner_type: dest_owner_type.to_s,
      dest_owner_id: dest_owner_id.to_s,
      amount_cents: amount_cents,
      currency: currency,
      status: 'authorized',
      source_hold_id: source_hold_ref,
      metadata: metadata,
      authorized_at: Time.now
    }
    @@transactions[transfer_ref] = transfer_txn

    {
      status: 'authorized',
      provider: 'fake_baas',
      provider_reference: transfer_ref,
      source_hold_id: source_hold_ref,
      authorized_at: Time.now,
      transfer_id: transfer_ref
    }
  end

  # Complete a transfer (via source_hold_id and transfer_id)
  def complete_transfer(transfer_reference:)
    transfer_txn = @@transactions[transfer_reference]
    return { status: 'error', error: 'transfer_not_found' } unless transfer_txn

    source_hold_id = transfer_txn[:source_hold_id]
    source_hold = @@holds[source_hold_id]
    return { status: 'error', error: 'source_hold_not_found' } unless source_hold

    source_hold[:status] = 'completed_transfer'
    source_hold[:completed_at] = Time.now

    transfer_txn[:status] = 'captured'
    transfer_txn[:captured_at] = Time.now

    {
      status: 'captured',
      provider_reference: transfer_reference,
      source_hold_id: source_hold_id,
      captured_at: Time.now
    }
  end

  # Reverse a transfer (refund both source and destination)
  def reverse_transfer(transfer_reference:)
    transfer_txn = @@transactions[transfer_reference]
    return { status: 'error', error: 'transfer_not_found' } unless transfer_txn

    transfer_txn[:status] = 'reversed'
    transfer_txn[:reversed_at] = Time.now

    {
      status: 'reversed',
      provider_reference: transfer_reference,
      reversed_at: Time.now
    }
  end

  # Debug: get transaction state (for testing/demo only)
  def get_transaction(provider_reference:)
    @@transactions[provider_reference]
  end

  def get_hold(hold_reference:)
    @@holds[hold_reference]
  end
end
