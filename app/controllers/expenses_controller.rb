class ExpensesController < ApplicationController
  before_action :set_parents

  def index
    limit = params[:limit]&.to_i&.clamp(1, 500) || 100
    expenses = ExpenseEntriesRepository.list(@org_id, @campaign_id, limit)
    render json: expenses
  end

  def show
    expense = ExpenseEntriesRepository.find(@org_id, @campaign_id, params[:id])
    return head :not_found unless expense

    attachments = ExpenseAttachmentsRepository.list(@org_id, @campaign_id, expense[:entry_id])
    render json: expense.merge(attachments: attachments)
  end

  def create
    attrs = expense_params.merge(organization_id: @org_id, campaign_id: @campaign_id)
    result = ExpenseService.create(attrs)
    render json: result, status: :created, location: organization_campaign_expense_url(@org_id, @campaign_id, result[:entry_id])
  rescue ExpenseService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    result = ExpenseService.update(@org_id, @campaign_id, params[:id], expense_params)
    render json: result
  rescue ExpenseService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    ExpenseService.delete(@org_id, @campaign_id, params[:id])
    head :ok
  end

  private

  def set_parents
    @org_id = params[:organization_id]
    @campaign_id = params[:campaign_id]
  end

  def expense_params
    params.require(:expense).permit(:description, :amount_cents, :category, :expense_date, :status, :type)
  end
end
