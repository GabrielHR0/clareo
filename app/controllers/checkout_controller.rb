class CheckoutController < ApplicationController
  def create
    result = CheckoutService.process(deep_parse_params(checkout_params))

    case result[:status]
    when :ok
      render json: result, status: :created
    when :already_processed
      render json: result, status: :ok
    when :insufficient_funds
      render json: result, status: :unprocessable_entity
    else
      render json: result, status: :internal_server_error
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def deep_parse_params(params)
    case params
    when ActionController::Parameters
      deep_parse_params(params.to_unsafe_h)
    when Hash
      params.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_parse_params(v) }
    when Array
      params.map { |v| deep_parse_params(v) }
    else
      params
    end
  end

  def checkout_params
    params.require(:checkout).permit(
      :campaign_id,
      :amount_cents,
      :currency,
      :idempotency_key,
      contributor: [:name, :email, :cpf, :phone],
      payment: [:method, :card_token, :installments],
      metadata: {}
    )
  end
end
