class CreditLinesController < ApplicationController
  def index
    org_id = params[:organization_id]
    return render json: { error: "organization_id required" }, status: :bad_request unless org_id

    credits = CreditLinesRepository.find_by_organization(org_id)
    render json: credits
  end

  def show
    credit = CreditLinesRepository.find(params[:id])
    return render json: { error: "not_found" }, status: :not_found unless credit
    render json: credit
  end

  def create
    attrs = params.require(:credit_line).permit(:organization_id, :limit_cents, :annual_rate)
    credit = CreditService.create_line(
      organization_id: attrs[:organization_id],
      limit_cents: attrs[:limit_cents].to_i,
      annual_rate: attrs[:annual_rate] ? BigDecimal(attrs[:annual_rate].to_s) : nil
    )
    render json: credit, status: :created
  end

  def use
    amount = params.require(:amount_cents).to_i
    res = CreditService.use_credit(credit_id: params[:id], amount_cents: amount)
    case res[:status]
    when :ok
      render json: res[:credit], status: :ok
    when :insufficient
      render json: res, status: :unprocessable_entity
    when :not_found
      render json: res, status: :not_found
    else
      render json: res, status: :conflict
    end
  end

  def request_credit
    org_id = params.require(:organization_id)
    requested_cents = params.require(:amount_cents).to_i
    result = CreditRequestService.request_credit(organization_id: org_id, requested_cents: requested_cents)
    render json: result, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def bills
    org_id = params.require(:organization_id)
    bills = CreditBillsRepository.list(org_id)
    render json: bills
  end

  def pay_bill
    org_id = params.require(:organization_id)
    bill_id = params.require(:id)
    amount = (params[:amount_cents] || params[:amount] || 0).to_i
    result = CreditBillingService.pay_bill(org_id, bill_id, amount)
    case result[:status]
    when :ok
      render json: result, status: :ok
    when :not_found
      render json: result, status: :not_found
    when :already_paid
      render json: result, status: :unprocessable_entity
    else
      render json: result, status: :unprocessable_entity
    end
  end
end
