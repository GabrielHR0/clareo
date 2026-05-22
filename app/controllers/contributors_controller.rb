# frozen_string_literal: true

class ContributorsController < ApplicationController
  def index
    render json: []
  end

  def show
    contributor = ContributorsRepository.find(params[:id])

    if contributor
      render json: contributor
    else
      head :not_found
    end
  end

  def create
    attrs = contributor_params.to_h.symbolize_keys
    id = ContributorsRepository.create(attrs)

    render json: { contributor_id: id }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def contributor_params
    params.require(:contributor).permit(
      :id,
      :contributor_id,
      :name,
      :email,
      :cpf,
      :phone,
      :status
    )
  end
end
