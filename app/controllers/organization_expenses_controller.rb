class OrganizationExpensesController < ApplicationController
  SENTINEL = "00000000-0000-0000-0000-000000000000"

  def index
    limit = params[:limit]&.to_i&.clamp(1, 500) || 100
    expenses = ExpenseEntriesRepository.list_by_org(params[:organization_id], limit)
    render json: expenses
  end

  def show
    expense = ExpenseEntriesRepository.find(params[:organization_id], SENTINEL, params[:id])
    return head :not_found unless expense

    attachments = ExpenseAttachmentsRepository.list(params[:organization_id], SENTINEL, expense[:entry_id])
    render json: expense.merge(attachments: attachments)
  end

  def create
    attrs = expense_params.merge(organization_id: params[:organization_id])
    result = ExpenseService.create(attrs)
    render json: result, status: :created
  rescue ExpenseService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    attrs = expense_params
    result = ExpenseService.update(params[:organization_id], SENTINEL, params[:id], attrs)
    render json: result
  rescue ExpenseService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    ExpenseService.delete(params[:organization_id], SENTINEL, params[:id])
    head :ok
  end

  private

  def expense_params
    params.require(:expense).permit(:description, :amount_cents, :category, :expense_date, :status, :type)
  end
end
