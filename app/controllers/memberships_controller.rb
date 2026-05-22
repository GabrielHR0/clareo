# frozen_string_literal: true

class MembershipsController < ApplicationController
  def index
    if params[:organization_id].present?
      render json: MembershipsRepository.for_organization(params[:organization_id])
    elsif params[:contributor_id].present?
      render json: MembershipsRepository.for_contributor(params[:contributor_id])
    else
      render json: [], status: :ok
    end
  end

  def create
    attrs = membership_params.to_h.symbolize_keys
    id = MembershipsRepository.create(attrs)

    render json: { membership_id: id }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def membership_params
    params.require(:membership).permit(
      :membership_id,
      :organization_id,
      :contributor_id,
      :status
    )
  end
end
