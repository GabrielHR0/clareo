class AssociationsController < ApplicationController
  before_action :set_contributor

  def index
    memberships = MembershipsRepository.for_contributor(@contributor_id)

    enriched = memberships.map do |m|
      org = OrganizationsRepository.find(m[:organization_id])
      next unless org

      campaigns = CampaignsRepository.list(org[:organization_id], 5) rescue []

      m.merge(
        organization_name: org[:name],
        organization_status: org[:status],
        campaigns_count: campaigns.size,
        campaigns: campaigns.map { |c| { campaign_id: c[:campaign_id], name: c[:name], status: c[:status] } }
      )
    end.compact

    render json: enriched
  end

  def create
    org_id = params[:organization_id]
    return render json: { error: "organization_id required" }, status: :unprocessable_entity unless org_id

    org = OrganizationsRepository.find(org_id)
    return render json: { error: "Organization not found" }, status: :not_found unless org

    existing = MembershipsRepository.for_contributor(@contributor_id)
    if existing.any? { |m| m[:organization_id] == org_id }
      return render json: { error: "Already associated with this organization" }, status: :conflict
    end

    membership_id = MembershipsRepository.create(
      organization_id: org_id,
      contributor_id: @contributor_id,
      status: "active"
    )

    render json: { membership_id: membership_id.to_s, organization_id: org_id }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    org_id = params[:organization_id]
    return render json: { error: "organization_id required" }, status: :unprocessable_entity unless org_id

    MembershipsRepository.remove(org_id, @contributor_id)
    head :no_content
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_contributor
    user = UsersRepository.find(@current_user[:user_id])
    return render json: { error: "User not found" }, status: :not_found unless user

    @contributor_id = user[:contributor_id]

    unless @contributor_id
      result = CreateContributorService.call(name: user[:name], email: user[:email])
      contributor = result[:contributor]
      @contributor_id = contributor[:contributor_id].to_s
      UsersRepository.update(user[:user_id], contributor_id: @contributor_id)
    end
  end
end
