class ContributorsController < ApplicationController
  def index
    render json: []
  end

  def create
    result = CreateContributorService.call(contributor_params.to_h.symbolize_keys)

    render json: result, status: :created, location: contributor_url(result[:contributor][:contributor_id])
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show

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
