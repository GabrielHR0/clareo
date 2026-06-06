class CampaignsController < ApplicationController
  before_action :set_organization

  def index
    limit = params[:limit]&.to_i&.clamp(1, 500) || 100
    campaigns = CampaignsRepository.list(@org_id, limit)
    render json: campaigns
  end

  def show
    campaign = CampaignsRepository.find(@org_id, params[:id])
    if campaign
      render json: campaign
    else
      head :not_found
    end
  end

  def create
    result = CampaignService.create(campaign_params.merge(organization_id: @org_id))
    render json: result, status: :created, location: organization_campaign_url(@org_id, result[:campaign_id])
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_organization
    @org_id = params[:organization_id]
  end

  def campaign_params
    params.require(:campaign).permit(
      :name,
      :description,
      :goal_cents,
      :starts_at,
      :ends_at,
      :status,
      metadata: {}
    )
  end
end
