class ApplicationController < ActionController::API
	rescue_from StandardError, with: :render_internal_error

	private

	def render_internal_error(exception)
		Rails.logger.error(exception.full_message(highlight: false, order: :top))

		render json: {
			error: exception.class.name,
			message: exception.message
		}, status: :internal_server_error
	end
end
