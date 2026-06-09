# Manages JWT token blacklisting via Redis for distributed auth.
# When a user logs out, their token's jti is stored in Redis with a TTL
# matching the remaining token expiry. All instances check this before
# accepting a token.
#
# We also maintain a whitelist of recently-issued tokens so that when
# a user logs in on instance A, instance B doesn't reject them immediately
# due to eventual consistency (if using a whitelist approach).
#
# Using blacklist rather than whitelist because:
# - Most tokens are valid, so the blacklist is small
# - TTL-based expiry is automatic
# - Memory usage is O(revoked_tokens) rather than O(all_tokens)

module TokenBlacklist
  BLACKLIST_PREFIX = "token:blacklist:"
  WHITELIST_PREFIX = "token:whitelist:"

  class << self
    # Blacklist a token (call on logout)
    def blacklist!(jti, exp)
      ttl = exp - Time.now.to_i
      return if ttl <= 0

      $redis.with do |conn|
        conn.setex("#{BLACKLIST_PREFIX}#{jti}", ttl, "1")
      end
    end

    # Check if a token has been blacklisted (call on every auth)
    def blacklisted?(jti)
      $redis.with { |conn| conn.exists("#{BLACKLIST_PREFIX}#{jti}") == 1 }
    end

    # Whitelist a token (call on login/register)
    def whitelist!(jti, exp)
      ttl = exp - Time.now.to_i
      return if ttl <= 0

      $redis.with do |conn|
        conn.setex("#{WHITELIST_PREFIX}#{jti}", ttl, "1")
      end
    end

    # Check if a token is whitelisted (optional, for extra security)
    def whitelisted?(jti)
      $redis.with { |conn| conn.exists("#{WHITELIST_PREFIX}#{jti}") == 1 }
    end

    # Remove expired entries (called periodically or on startup)
    def cleanup!
      # Redis handles TTL-based expiry automatically — nothing to do
    end
  end
end
