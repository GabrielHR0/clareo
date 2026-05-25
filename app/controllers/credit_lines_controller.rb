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
      annual_rate: attrs[:annual_rate]
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
end
