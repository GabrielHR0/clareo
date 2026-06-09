# Cleans up stale distributed locks and idempotency keys.
# Runs every 6 hours via sidekiq-cron.
#
# Redis auto-expires locks via TTL, but this worker provides
# an additional safety net and logging for long-held locks.

class StaleLockCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 2

  def perform
    Rails.logger.info("StaleLockCleanupWorker: scanning for stale locks")

    # Redis handles TTL-based expiry automatically.
    # This worker is a safety net and monitoring tool.
    # If we find locks held for > 5 minutes, log a warning.

    scan_for_long_locks
  end

  private

  def scan_for_long_locks
    $redis.with do |conn|
      cursor = "0"
      loop do
        cursor, keys = conn.scan(cursor, match: "lock:*", count: 100)
        keys.each do |key|
          ttl = conn.ttl(key)
          if ttl > 300 # Held for more than 5 minutes — suspicious
            Rails.logger.warn("Stale lock detected: #{key} TTL=#{ttl}s")
          end
        end
        break if cursor == "0"
      end
    end
  rescue Redis::BaseConnectionError => e
    Rails.logger.error("StaleLockCleanupWorker: Redis error: #{e.message}")
  end
end
