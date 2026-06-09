# Cleans up expired session/blacklist entries.
# Redis handles TTL-based expiry automatically, but this worker
# provides logging and metrics about blacklist size.

class ExpiredSessionCleanupWorker
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 2

  def perform
    Rails.logger.info("ExpiredSessionCleanupWorker: checking token blacklist")

    $redis.with do |conn|
      cursor = "0"
      blacklist_count = 0
      loop do
        cursor, keys = conn.scan(cursor, match: "token:blacklist:*", count: 100)
        blacklist_count += keys.size
        break if cursor == "0"
      end
      Rails.logger.info("ExpiredSessionCleanupWorker: #{blacklist_count} blacklisted tokens")
    end
  rescue Redis::BaseConnectionError => e
    Rails.logger.error("ExpiredSessionCleanupWorker: Redis error: #{e.message}")
  end
end
