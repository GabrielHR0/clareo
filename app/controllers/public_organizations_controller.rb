class PublicOrganizationsController < ApplicationController
  skip_before_action :authenticate!

  def index
    organizations = OrganizationsRepository.all
    filtered = organizations.map { |o|
      {
        organization_id: o[:organization_id],
        name: o[:name],
        contact_email: o[:contact_email],
        status: o[:status]
      }
    }.select { |o| o[:status] != "inactive" }

    render json: filtered
  end
end
