class DistributedLock
  LockError = Class.new(StandardError)

  DEFAULT_TTL = 30
  RETRY_DELAY = 0.1
  MAX_RETRIES = 10

  # Acquire a distributed lock and execute the block.
  # Raises LockError if the lock cannot be acquired within retries.
  def self.acquire!(key, ttl: DEFAULT_TTL, retries: MAX_RETRIES)
    lock_key = "lock:#{key}"
    lock_value = SecureRandom.hex(16)

    retries.times do |attempt|
      $redis.with do |conn|
        acquired = conn.set(lock_key, lock_value, nx: true, ex: ttl)
        if acquired
          begin
            return yield
          ensure
            release(lock_key, lock_value)
          end
        end
      end
      sleep RETRY_DELAY * (2 ** attempt)
    end

    raise LockError, "Could not acquire lock for key: #{key}"
  end

  # Try to acquire without retry. Returns nil if lock is held.
  def self.try_acquire!(key, ttl: DEFAULT_TTL)
    lock_key = "lock:#{key}"
    lock_value = SecureRandom.hex(16)

    $redis.with do |conn|
      acquired = conn.set(lock_key, lock_value, nx: true, ex: ttl)
      if acquired
        begin
          return yield
        ensure
          release(lock_key, lock_value)
        end
      end
    end
    nil
  end

  # Check if a lock is currently held (without acquiring it)
  def self.locked?(key)
    $redis.with { |conn| conn.exists("lock:#{key}") }
  end

  private

  def self.release(lock_key, lock_value)
    $redis.with do |conn|
      # Only release if we still hold the lock (prevent releasing someone else's)
      current = conn.get(lock_key)
      conn.del(lock_key) if current == lock_value
    end
  end
end
