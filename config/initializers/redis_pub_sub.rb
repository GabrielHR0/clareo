# Redis pub/sub listener for cross-instance event distribution.
# Runs in a background thread within each Rails instance.
#
# When an event is published on any instance, ALL instances receive it.
# This enables:
# - Cache invalidation across instances
# - Real-time feed updates
# - Distributed state synchronization
#
# For durability, events are ALSO processed via Sidekiq (EventProcessorJob).
# The pub/sub listener handles lightweight, real-time tasks.
# Sidekiq handles durable, retryable processing.

unless defined?(Rails::Console) || Rails.env.test?
  Thread.new do
    begin
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      redis.subscribe(EventBus::CHANNEL) do |on|
        on.message do |channel, message|
          begin
            event = JSON.parse(message, symbolize_names: true)
            next unless event[:source] != EventBus::SOURCE

            Rails.logger.debug("PubSub received: #{event[:type]} from #{event[:source]}")

            case event[:type]
            when "cache.invalidate"
              pattern = event.dig(:data, :pattern)
              RedisCache.delete_matched(pattern) if pattern
            when "organization.created", "campaign.updated", "expense.created"
              pattern = event.dig(:data, :organization_id)
              RedisCache.delete_matched("dashboard:#{pattern}") if pattern
            end
          rescue JSON::ParserError => e
            Rails.logger.error("PubSub parse error: #{e.message}")
          end
        end
      end
    rescue => e
      Rails.logger.error("Redis pub/sub listener error: #{e.message}")
      sleep 5
      retry
    end
  end
end
