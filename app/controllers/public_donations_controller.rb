class PublicDonationsController < ApplicationController
  skip_before_action :authenticate!

  def create
    org = OrganizationsRepository.find(params[:organization_id])
    return render json: { error: "Organization not found" }, status: :not_found unless org

    result = DirectDonationService.call(
      organization_id: org[:organization_id],
      contributor_attrs: deep_parse_params(donation_params[:contributor] || {}),
      amount_cents: donation_params[:amount_cents],
      currency: donation_params[:currency],
      payment: deep_parse_params(donation_params[:payment] || {}),
      idempotency_key: donation_params[:idempotency_key],
      metadata: deep_parse_params(donation_params[:metadata] || {})
    )

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

  def donation_params
    params.require(:donation).permit(
      :amount_cents,
      :currency,
      :idempotency_key,
      contributor: [:name, :email, :cpf, :phone],
      payment: [:method, :card_token, :installments],
      metadata: {}
    )
  end
end
