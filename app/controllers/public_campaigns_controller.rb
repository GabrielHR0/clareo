class PublicCampaignsController < ApplicationController
  skip_before_action :authenticate!

  def index
    tag = params[:tag]
    limit = params[:limit]&.to_i&.clamp(1, 100) || 50

    all_rows = if tag.present?
      CampaignsByTagRepository.list_by_tag(tag, limit)
    else
      CampaignsByTagRepository.list_all(limit * 3)
    end

    all_tags = all_rows.map { |r| r[:tag] }.compact.uniq

    seen = Set.new
    campaigns = all_rows.select { |c| seen.add?(c[:campaign_id]) }.first(limit)

    render json: { campaigns: campaigns, tags: all_tags }
  end
end
