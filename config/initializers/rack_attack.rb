class Rack::Attack
  # Attempt to use Redis as the cache store for distributed rate limiting.
  # Falls back to memory store if unavailable.
  begin
    cache.store = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  rescue StandardError, ArgumentError => e
    Rails.logger.warn "Rack::Attack Redis store unavailable (#{e.message}), using memory store"
  end

  unless Rails.env.test?
    # General API throttle: 300 requests per minute per IP
    throttle("api/ip", limit: 300, period: 1.minute) do |req|
      req.ip
    end

    # Checkout endpoint: stricter limit (20 req/min per IP)
    throttle("public/checkout/ip", limit: 20, period: 1.minute) do |req|
      req.ip if req.path.include?("/public/checkout")
    end

    # Auth endpoints: prevent brute force (10 req/min per IP)
    throttle("auth/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path.include?("/auth/login") || req.path.include?("/auth/register")
    end

    # Per-user API throttle: 1000 req/min per authenticated user
    throttle("api/user", limit: 1000, period: 1.minute) do |req|
      if req.env["HTTP_AUTHORIZATION"]&.start_with?("Bearer ")
        token = req.env["HTTP_AUTHORIZATION"].split(" ").last
        begin
          payload = JwtAuth.decode(token)
          payload ? "user:#{payload['user_id']}" : nil
        rescue StandardError
          nil
        end
      end
    end

    # Wallet transactions: prevent abuse (30 req/min per owner)
    throttle("wallet/owner", limit: 30, period: 1.minute) do |req|
      if req.path.include?("/transactions") && req.post?
        match = req.path.match(%r{/owners/([^/]+)/([^/]+)/transactions})
        match ? "wallet:#{match[1]}:#{match[2]}" : nil
      end
    end

    self.throttled_responder = lambda do |env|
      headers = {
        "Content-Type" => "application/json",
        "Retry-After" => "60"
      }
      [429, headers, [{ error: "Rate limit exceeded. Try again later." }.to_json]]
    end
  end
end
