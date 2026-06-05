require "digest"

class ApplicationController < ActionController::API
	rescue_from StandardError, with: :render_internal_error

	before_action :authenticate!

	private

	def authenticate!
		return if skip_auth?

		api_key = request.headers["X-API-Key"]
		return render_unauthorized("API key required") unless api_key

		hash = Digest::SHA256.base64digest(api_key)
		@current_organization = OrganizationsRepository.find_by_api_key_hash(hash)
		render_unauthorized("Invalid API key") unless @current_organization
	end

	def skip_auth?
		Rails.env.test? || public_path?
	end

	def public_path?
		path = request.path
		path == "/up" ||
		path.start_with?("/health", "/api-docs") ||
		path.include?("/public/")
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
