class RecurringDonationsController < ApplicationController
  before_action :set_contributor

  def index
    donations = RecurringDonationsRepository.list_by_contributor(@contributor_id)
    render json: donations
  end

  def create
    result = RecurringDonationService.create(recurring_params.merge(contributor_id: @contributor_id))
    render json: result, status: :created, location: contributor_recurring_donation_url(@contributor_id, result[:recurring_id])
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
    @contributor_id = params[:contributor_id]
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
