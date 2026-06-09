class ContributorsController < ApplicationController
  def index
    if params[:organization_id].present?
      memberships = MembershipsRepository.for_organization(params[:organization_id])
      contributor_ids = memberships.map { |m| m[:contributor_id] }.compact.uniq
      contributors = contributor_ids.map { |id| ContributorsRepository.find(id) }.compact
    else
      contributors = ContributorsRepository.all
    end
    render json: contributors
  end

  def show
    contributor = ContributorsRepository.find(params[:id])
    if contributor
      render json: contributor
    else
      head :not_found
    end
  end
end
