require "connection_pool"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
redis_pool_size = ENV.fetch("REDIS_POOL_SIZE", 10).to_i
redis_timeout = ENV.fetch("REDIS_TIMEOUT", 5).to_i

puts ">>> Initializing Redis pool: url=#{redis_url}, size=#{redis_pool_size}, timeout=#{redis_timeout}"

$redis = ConnectionPool.new(size: redis_pool_size, timeout: redis_timeout) do
  Redis.new(url: redis_url)
end

puts ">>> Redis pool initialized, class=#{$redis.class}"

# Sidekiq already configures its own Redis connection via REDIS_URL.
# $redis is our application-level pool for caching, locks, rate limiting, etc.

Rails.logger.info "Redis pool initialized: size=#{redis_pool_size}"
