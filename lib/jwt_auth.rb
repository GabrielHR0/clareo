require "jwt"
require "securerandom"

module JwtAuth
  SECRET = ENV.fetch("JWT_SECRET", "clareo_dev_secret_change_in_production")
  ALGORITHM = "HS256"
  DEFAULT_EXPIRY = 24.hours

  # Encode a payload into a JWT token with jti (JWT ID) for blacklisting.
  #
  # The jti is a UUID that uniquely identifies this token.
  # When a user logs out, the jti is added to the Redis blacklist.
  # All instances check the blacklist before accepting a token.
  def self.encode(payload, exp = DEFAULT_EXPIRY.from_now)
    payload = payload.dup
    payload[:jti] ||= SecureRandom.uuid
    payload[:exp] = exp.to_i
    payload[:iat] = Time.now.to_i
    payload[:iss] = "clareo"

    JWT.encode(payload, SECRET, ALGORITHM)
  end

  # Decode and verify a JWT token.
  # Returns the payload hash, or nil if invalid/expired.
  #
  # NOTE: This does NOT check the blacklist — that's the caller's
  # responsibility (see ApplicationController#authenticate_with_jwt!).
  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, {
      algorithm: ALGORITHM,
      iss: "clareo",
      verify_iss: true
    })
    Hash[decoded.first.map { |k, v| [k.to_sym, v] }]
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError
    nil
  end

  # Extract the jti (JWT ID) from a token without full verification.
  # Used for blacklist checks before the token expires.
  def self.extract_jti(token)
    payload = JWT.decode(token, SECRET, false, algorithm: ALGORITHM)
    payload.first&.dig("jti")
  rescue JWT::DecodeError
    nil
  end
end
