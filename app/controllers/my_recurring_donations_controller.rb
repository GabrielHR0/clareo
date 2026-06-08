class MyRecurringDonationsController < ApplicationController
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
    attrs = recurring_params.to_h.symbolize_keys.merge(contributor_id: @contributor_id)
    result = RecurringDonationService.create(attrs)

    render json: result, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    recurring_id = params[:id]
    org_id = params[:organization_id]

    return render json: { error: "organization_id required" }, status: :unprocessable_entity unless org_id

    donation = RecurringDonationsRepository.find(org_id, @contributor_id, recurring_id)
    return head :not_found unless donation

    RecurringDonationsRepository.cancel(org_id, @contributor_id, recurring_id)
    head :ok
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
