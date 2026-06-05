class PublicAccountabilityController < ApplicationController
  def show
    campaign = CampaignsByIdRepository.find(params[:campaign_id])
    return head :not_found unless campaign

    report = ExpenseService.accountability(campaign[:organization_id], params[:campaign_id])
    return head :not_found unless report

    render json: report
  end
end
