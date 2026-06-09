# Generic event processor job.
# Receives events from EventBus and dispatches them to the appropriate handler.
#
# This is the durable consumer side of the event-driven architecture.
# Redis pub/sub delivers events in real-time to all instances,
# Sidekiq ensures at-least-once processing.
#
# Events are deduplicated by event_id using Redis SETNX.
# This prevents duplicate processing when:
# - Two instances receive the same pub/sub message
# - Sidekiq retries the job

class EventProcessorJob
  include Sidekiq::Job
  sidekiq_options queue: :events, retry: 5

  PROCESSED_PREFIX = "event:processed:"
  PROCESSED_TTL = 7 * 24 * 3600 # 7 days
  LOCK_TTL = 30

  def perform(event)
    event = event.with_indifferent_access if event.is_a?(Hash)
    event_id = event[:event_id] || event["event_id"]
    event_type = event[:type] || event["type"]

    # Deduplication: skip if already processed
    return if already_processed?(event_id)

    # Acquire a short-lived lock to prevent concurrent processing
    DistributedLock.acquire!("event:#{event_id}", ttl: LOCK_TTL) do
      # Double-check after acquiring lock
      return if already_processed?(event_id)

      Rails.logger.info("Processing event: #{event_type} (#{event_id})")

      case event_type
      when "donation.created"
        handle_donation_created(event)
      when "donation.redeemed"
        handle_donation_redeemed(event)
      when "expense.created"
        handle_expense_created(event)
      when "wallet.transaction"
        handle_wallet_transaction(event)
      when "credit.requested"
        handle_credit_requested(event)
      when "credit.bill.paid"
        handle_credit_bill_paid(event)
      when "organization.created"
        handle_organization_created(event)
      when "user.registered"
        handle_user_registered(event)
      else
        Rails.logger.warn("Unknown event type: #{event_type}")
      end

      mark_processed(event_id)
    end
  rescue DistributedLock::LockError
    Rails.logger.warn("Event lock contention: #{event_id}, retrying...")
    raise # Sidekiq will retry
  end

  private

  def already_processed?(event_id)
    $redis.with { |conn| conn.exists("#{PROCESSED_PREFIX}#{event_id}") }
  end

  def mark_processed(event_id)
    $redis.with do |conn|
      conn.setex("#{PROCESSED_PREFIX}#{event_id}", PROCESSED_TTL, "1")
    end
  end

  def handle_donation_created(event)
    data = event[:data] || event["data"] || {}
    org_id = data[:organization_id] || data["organization_id"]
    campaign_id = data[:campaign_id] || data["campaign_id"]
    amount_cents = data[:amount_cents] || data["amount_cents"]

    Rails.logger.info("Donation created: org=#{org_id}, campaign=#{campaign_id}, amount=#{amount_cents}")

    # Check if this donation should apply to a credit line
    CreditRepaymentWorker.new.perform if org_id
  end

  def handle_donation_redeemed(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Donation redeemed: #{data[:campaign_id]}")
  end

  def handle_expense_created(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Expense created: #{data[:description]}")
  end

  def handle_wallet_transaction(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Wallet transaction: #{data[:owner_type]} #{data[:owner_id]}")

    # Update dashboard cache
    org_id = data[:organization_id] || data["organization_id"]
    if org_id
      RedisCache.delete("dashboard:#{org_id}")
    end
  end

  def handle_credit_requested(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Credit requested: org=#{data[:organization_id]}, amount=#{data[:amount_cents]}")
  end

  def handle_credit_bill_paid(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Credit bill paid: org=#{data[:organization_id]}, bill=#{data[:bill_id]}")
  end

  def handle_organization_created(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("Organization created: #{data[:name]}")
  end

  def handle_user_registered(event)
    data = event[:data] || event["data"] || {}
    Rails.logger.info("User registered: #{data[:email]}")
  end
end
