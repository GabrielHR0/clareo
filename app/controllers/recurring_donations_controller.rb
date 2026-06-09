class RecurringDonationsController < ApplicationController
  before_action :set_contributor

  def index
    donations = RecurringDonationsRepository.list_by_contributor(@contributor_id)

    enriched = donations.map do |d|
      org = OrganizationsRepository.find(d[:organization_id])
      d.merge(organization_name: org ? org[:name] : nil)
    end

    render json: enriched
  end

  def create
    result = RecurringDonationService.create(recurring_params.merge(contributor_id: @contributor_id))
    render json: result, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    org_id = org_id_from_params
    return head :bad_request unless org_id

    donation = RecurringDonationsRepository.find(org_id, @contributor_id, params[:id])
    return head :not_found unless donation

    RecurringDonationsRepository.cancel(org_id, @contributor_id, params[:id])
    head :ok
  end

  def destroy
    org_id = org_id_from_params
    return head :bad_request unless org_id

    donation = RecurringDonationsRepository.find(org_id, @contributor_id, params[:id])
    return head :not_found unless donation

    RecurringDonationsRepository.cancel(org_id, @contributor_id, params[:id])
    head :ok
  end

  private

  def org_id_from_params
    params[:organization_id] || params.dig(:recurring_donation, :organization_id)
  end

  def set_contributor
    user_id = params[:user_id] || @current_user&.dig(:user_id)

    if user_id
      user = user_id == @current_user&.dig(:user_id) ? @current_user : UsersRepository.find(user_id)
      return render json: { error: "User not found" }, status: :not_found unless user

      @contributor_id = user[:contributor_id]

      unless @contributor_id
        result = CreateContributorService.call(name: user[:name], email: user[:email])
        contributor = result[:contributor]
        @contributor_id = contributor[:contributor_id].to_s
        UsersRepository.update(user[:user_id], contributor_id: @contributor_id)
      end
    else
      @contributor_id = params[:contributor_id]
    end
  end

  def recurring_params
    params.require(:recurring_donation).permit(
      :organization_id,
      :amount_cents,
      :currency,
      :payment_method,
      :card_reference,
      :interval_days,
      :campaign_id,
      :next_charge_date
    )
  end
end
