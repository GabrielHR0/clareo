class Rack::Attack
  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip
  end

  throttle("public/checkout/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.include?("/public/checkout")
  end

  self.throttled_responder = lambda do |env|
    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => "60"
    }
    [429, headers, [{ error: "Rate limit exceeded. Try again later." }.to_json]]
  end
end
