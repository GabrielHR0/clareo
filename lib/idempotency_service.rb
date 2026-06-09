# Distributed idempotency service using Redis + Cassandra.
#
# Pattern: Redis for fast path (first check), Cassandra for durable storage.
# This is the "hybrid approach" used by high-scale fintechs.
#
# Flow:
# 1. Client sends request with idempotency key
# 2. Check Redis cache — if found, return cached response
# 3. Check Cassandra — if found, cache in Redis and return
# 4. If not found anywhere, acquire distributed lock on the key
# 5. Execute business logic
# 6. Store result in Cassandra (durable) and Redis (fast cache)

class IdempotencyService
  RedisCacheError = Class.new(StandardError)
  DuplicateKeyError = Class.new(StandardError)
  LockError = Class.new(StandardError)

  REDIS_PREFIX = "idempotency:"
  REDIS_TTL = 24 * 3600 # 24 hours

  class << self
    # Process a request idempotently.
    # Returns the cached response if already processed, or yields to the block.
    def process!(owner_type:, owner_id:, idempotency_key:, request_hash: nil)
      redis_key = "#{REDIS_PREFIX}#{owner_type}:#{owner_id}:#{idempotency_key}"

      # Step 1: Fast path — check Redis cache
      cached = check_redis_cache(redis_key)
      return cached if cached

      # Step 2: Check Cassandra (durable storage)
      existing = IdempotencyKeysByOwnerRepository.find(
        owner_type, owner_id, idempotency_key
      )
      if existing
        # Cache in Redis for future fast lookups
        cache_in_redis(redis_key, existing)
        return existing
      end

      # Step 3: Acquire distributed lock to prevent concurrent processing
      result = DistributedLock.acquire!(redis_key, ttl: 30) do
        # Double-check after acquiring lock
        rechecked = IdempotencyKeysByOwnerRepository.find(
          owner_type, owner_id, idempotency_key
        )
        if rechecked
          cache_in_redis(redis_key, rechecked)
          return rechecked
        end

        if request_hash
          existing = IdempotencyKeysByOwnerRepository.find_by_hash(
            owner_type, owner_id, request_hash
          )
          if existing && existing[:idempotency_key] != idempotency_key
            raise DuplicateKeyError,
              "Idempotency key mismatch: same request_hash used with different key"
          end
        end

        # Yield to the caller to execute the business logic
        result = yield

        # Store in Cassandra (durable)
        store_in_cassandra(
          owner_type: owner_type,
          owner_id: owner_id,
          idempotency_key: idempotency_key,
          request_hash: request_hash,
          result: result
        )

        # Cache in Redis
        cache_in_redis(redis_key, result)
        cache_in_redis("#{redis_key}:hash:#{request_hash}", result) if request_hash

        result
      end

      result
    rescue DistributedLock::LockError
      raise LockError, "Concurrent request detected for key: #{idempotency_key}"
    end

    private

    def check_redis_cache(key)
      $redis.with do |conn|
        cached = conn.get(key)
        cached ? JSON.parse(cached, symbolize_names: true) : nil
      end
    rescue Redis::BaseConnectionError
      nil # Graceful degradation — fall through to Cassandra
    end

    def cache_in_redis(key, data)
      $redis.with do |conn|
        conn.setex(key, REDIS_TTL, data.to_json)
      end
    rescue Redis::BaseConnectionError
      # Non-critical — Cassandra is the source of truth
      nil
    end

    def store_in_cassandra(owner_type:, owner_id:, idempotency_key:, request_hash:, result:)
      IdempotencyKeysByOwnerRepository.create(
        owner_type: owner_type,
        owner_id: owner_id,
        idempotency_key: idempotency_key,
        transaction_id: result[:transaction_id],
        request_hash: request_hash
      )
    end
  end
end
