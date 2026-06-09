class OrganizationsController < ApplicationController
  def index
    limit = params[:limit]&.to_i&.clamp(1, 500) || 100
    organizations = OrganizationsRepository.all(params[:owner_user_id], limit)
    render json: organizations
  end

  def show
    organization_id = params[:id]
    org = OrganizationsRepository.find(organization_id)

    if org
      render json: org
    else
      head :not_found
    end
  end

  def create
    result = CreateOrganizationService.call(organization_params.to_h.symbolize_keys)

    render json: result, status: :created, location: organization_url(result[:organization][:organization_id])
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def organization_params
    params.require(:organization).permit(
      :id,
      :organization_id,
      :name,
      :cnpj,
      :status,
      :contact_email,
      :webhook_url,
      :api_key_hash,
      :owner_user_id
    )
  end
end
