require "jwt"

module JwtAuth
  SECRET = ENV.fetch("JWT_SECRET", "clareo_dev_secret_change_in_production")
  ALGORITHM = "HS256"

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, algorithm: ALGORITHM)
    decoded.first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
