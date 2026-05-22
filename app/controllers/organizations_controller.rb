class OrganizationsController < ApplicationController
  def index
    render json: []
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
    attrs = organization_params.to_h.symbolize_keys
    id = OrganizationsRepository.create(attrs)

    render json: { organization_id: id }, status: :created
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
      :api_key_hash
    )
  end
end
