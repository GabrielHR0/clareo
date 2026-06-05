class ExpenseAttachmentsController < ApplicationController
  before_action :set_parents

  def create
    expense = ExpenseEntriesRepository.find(@org_id, @campaign_id, params[:expense_id])
    return head :not_found unless expense

    uploaded = params[:file] || params.dig(:attachment, :file)
    return render json: { error: "file is required" }, status: :unprocessable_entity unless uploaded

    result = ExpenseAttachmentsRepository.create(@org_id, @campaign_id, params[:expense_id], uploaded)
    render json: result, status: :created
  end

  def download
    file_path = ExpenseAttachmentsRepository.file_path(@org_id, @campaign_id, params[:expense_id], params[:id])
    return head :not_found unless file_path

    record = ExpenseAttachmentsRepository.find(@org_id, @campaign_id, params[:expense_id], params[:id])
    send_file file_path, filename: record[:original_filename], type: record[:content_type]
  end

  def destroy
    ExpenseAttachmentsRepository.delete(@org_id, @campaign_id, params[:expense_id], params[:id])
    head :ok
  end

  private

  def set_parents
    @org_id = params[:organization_id]
    @campaign_id = params[:campaign_id]
  end
end
