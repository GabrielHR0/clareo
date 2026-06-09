# Redis-based cache for Cassandra query results.
#
# Cassandra is fast for write-heavy workloads but read latency
# can be 5-50ms per query. Redis provides sub-millisecond reads.
#
# This cache is used for frequently accessed, rarely changed data:
# - Organization details
# - Campaign metadata
# - Contributor profiles
# - Dashboard aggregates
#
# Cache invalidation:
# - Explicit: RedisCache.delete(key) when data changes
# - TTL-based: automatic expiry after configured duration
# - Event-driven: EventProcessorJob invalidates cache on data changes

module RedisCache
  PREFIX = "cache:"
  DEFAULT_TTL = 5 * 60 # 5 minutes

  class << self
    # Fetch from cache or execute block and cache result.
    def fetch(key, ttl: DEFAULT_TTL)
      cache_key = "#{PREFIX}#{key}"

      $redis.with do |conn|
        cached = conn.get(cache_key)
        if cached
          return JSON.parse(cached, symbolize_names: true)
        end
      end

      result = yield

      $redis.with do |conn|
        conn.setex(cache_key, ttl, result.to_json)
      end

      result
    rescue Redis::BaseConnectionError
      yield # Graceful degradation on Redis failure
    end

    # Read from cache without fallback.
    def read(key)
      cache_key = "#{PREFIX}#{key}"
      $redis.with do |conn|
        cached = conn.get(cache_key)
        cached ? JSON.parse(cached, symbolize_names: true) : nil
      end
    rescue Redis::BaseConnectionError
      nil
    end

    # Write to cache explicitly.
    def write(key, value, ttl: DEFAULT_TTL)
      cache_key = "#{PREFIX}#{key}"
      $redis.with do |conn|
        conn.setex(cache_key, ttl, value.to_json)
      end
    rescue Redis::BaseConnectionError
      nil
    end

    # Delete from cache.
    def delete(key)
      cache_key = "#{PREFIX}#{key}"
      $redis.with { |conn| conn.del(cache_key) }
    rescue Redis::BaseConnectionError
      nil
    end

    # Delete all cached values matching a pattern.
    def delete_matched(pattern)
      $redis.with do |conn|
        cursor = "0"
        loop do
          cursor, keys = conn.scan(cursor, match: "#{PREFIX}#{pattern}", count: 100)
          conn.del(*keys) if keys.any?
          break if cursor == "0"
        end
      end
    rescue Redis::BaseConnectionError
      nil
    end

    # Clear the entire cache.
    def clear!
      $redis.with do |conn|
        cursor = "0"
        loop do
          cursor, keys = conn.scan(cursor, match: "#{PREFIX}*", count: 100)
          conn.del(*keys) if keys.any?
          break if cursor == "0"
        end
      end
    rescue Redis::BaseConnectionError
      nil
    end
  end
end
