require "digest"
require "jwt_auth"

class ApplicationController < ActionController::API
  rescue_from StandardError, with: :render_internal_error

  before_action :authenticate!

  private

  def authenticate!
    return if skip_auth?

    if bearer_token
      authenticate_with_jwt!
    elsif request.headers["X-API-Key"]
      authenticate_with_api_key!
    else
      render_unauthorized("Authentication required")
    end
  end

  def bearer_token
    auth = request.headers["Authorization"]
    auth&.start_with?("Bearer ") && auth.split(" ", 2).last
  end

  def authenticate_with_jwt!
    token = bearer_token
    payload = JwtAuth.decode(token)
    return render_unauthorized("Invalid or expired token") unless payload

    jti = payload[:jti]
    if jti && TokenBlacklist.blacklisted?(jti)
      return render_unauthorized("Token has been revoked")
    end

    @current_user = UsersRepository.find(payload[:user_id])
    render_unauthorized("User not found") unless @current_user

    if jti
      TokenBlacklist.whitelist!(jti, payload[:exp])
    end
  end

  def authenticate_with_api_key!
    api_key = request.headers["X-API-Key"]
    hash = Digest::SHA256.base64digest(api_key)
    @current_organization = OrganizationsRepository.find_by_api_key_hash(hash)
    render_unauthorized("Invalid API key") unless @current_organization
  end

  def skip_auth?
    Rails.env.test? || public_path? || auth_path?
  end

  def public_path?
    path = request.path
    path == "/up" ||
    path.start_with?("/health", "/api-docs") ||
    path.include?("/public/")
  end

  def auth_path?
    request.path.include?("/auth/register") || request.path.include?("/auth/login")
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end

  def render_internal_error(exception)
    Rails.logger.error(exception.full_message(highlight: false, order: :top))

    render json: {
      error: exception.class.name,
      message: exception.message
    }, status: :internal_server_error
  end
end
