class CampaignService
  def self.create(attrs)
    attrs[:campaign_id] ||= SecureRandom.uuid
    attrs[:status] ||= "draft"
    attrs[:raised_cents] ||= 0

    if attrs[:goal_cents].to_i < 0
      raise ArgumentError, "goal_cents must be non-negative"
    end

    id = CampaignsRepository.create(attrs)
    { campaign_id: id[:campaign_id].to_s, organization_id: id[:organization_id].to_s }
  end
end
