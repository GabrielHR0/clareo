# Distributed event bus using Redis pub/sub + Sidekiq.
#
# Pattern:
# 1. An operation happens (donation, redemption, expense, etc.)
# 2. The service publishes an event to Redis pub/sub
# 3. A background listener processes the event asynchronously
# 4. All instances receive the event via shared Redis
#
# For durability, events are ALSO enqueued as Sidekiq jobs.
# Redis pub/sub is "fire and forget" (no persistence) — Sidekiq
# provides the durable queue. This is the "dual delivery" pattern.
#
# Event schema:
#   {
#     event_id: "uuid",
#     type: "donation.created",
#     timestamp: "2026-06-09T12:00:00Z",
#     data: { organization_id: "...", amount_cents: 5000, ... },
#     source: "instance-1"
#   }

module EventBus
  CHANNEL = "clareo:events"
  SOURCE = ENV.fetch("HOSTNAME", "instance-#{SecureRandom.hex(4)}")

  class << self
    # Publish an event to Redis pub/sub AND enqueue a Sidekiq job.
    # All running instances receive the pub/sub message immediately.
    # Sidekiq provides durable queuing for recovery.
    def publish(event_type, data, metadata: {})
      event = {
        event_id: SecureRandom.uuid,
        type: event_type,
        timestamp: Time.now.utc.iso8601(3),
        data: data,
        source: SOURCE,
        metadata: metadata
      }

      # Publish to Redis pub/sub for real-time distribution
      publish_to_redis(event)

      # Enqueue Sidekiq job for durable processing
      enqueue_async(event)

      event
    end

    # Subscribe to a specific event type.
    # Returns a subscription ID for later unsubscription.
    def subscribe(event_type, &block)
      subscribers[event_type] << block
      # Return a unique ID for unsubscription
      SecureRandom.uuid
    end

    private

    def publish_to_redis(event)
      $redis.with do |conn|
        conn.publish(CHANNEL, event.to_json)
      end
    rescue Redis::BaseConnectionError => e
      Rails.logger.warn("EventBus: Redis pub/sub unavailable: #{e.message}")
    end

    def enqueue_async(event)
      # Deep stringify keys for Sidekiq 8 strict JSON validation
      stringified = deep_stringify_keys(event)
      EventProcessorJob.perform_async(stringified)
    end

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify_keys(v) }
      when Array
        value.map { |v| deep_stringify_keys(v) }
      else
        value
      end
    end

    def subscribers
      @subscribers ||= Hash.new { |h, k| h[k] = [] }
    end
  end
end
