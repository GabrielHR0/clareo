class TransactionsController < ApplicationController
  # GET /owners/:owner_type/:owner_id/transactions
  def index
    owner_type = normalize_owner_type(params[:owner_type])
    owner_id = params[:owner_id]
    limit = params[:limit]&.to_i || 100
    rows = TransactionsByOwnerRepository.find_by_owner(owner_id, owner_type, limit)
    render json: rows
  end

  # GET /owners/:owner_type/:owner_id/transactions/:id
  def show
    owner_type = normalize_owner_type(params[:owner_type])
    owner_id = params[:owner_id]
    tx_id = params[:id]
    rows = TransactionsByOwnerRepository.find_by_owner(owner_id, owner_type, 1000)
    tx = rows.find { |r| r[:transaction_id].to_s == tx_id.to_s }
    if tx
      render json: tx
    else
      render json: { error: 'not_found' }, status: :not_found
    end
  end

  # GET /campaigns/:campaign_id/transactions
  def by_campaign
    campaign_id = params[:campaign_id]
    limit = params[:limit]&.to_i || 100
    rows = TransactionsByCampaignRepository.find_by_campaign(campaign_id, limit)
    render json: rows
  end
  def create
    tx = transaction_params
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]

    result = ProcessTransactionService.call(
      owner_type: owner_type,
      owner_id: owner_id,
      amount_cents: tx[:amount_cents],
      currency: tx[:currency],
      transaction_type: tx[:transaction_type],
      idempotency_key: tx[:idempotency_key],
      campaign_id: tx[:campaign_id],
      metadata: tx[:metadata],
      dest_owner_type: tx[:dest_owner_type],
      dest_owner_id: tx[:dest_owner_id]
    )

    case result[:status]
    when :ok
      render json: result, status: :created, location: owner_wallet_path(owner_type: owner_type, owner_id: owner_id)
    when :already_processed
      render json: result, status: :ok
    when :insufficient_funds
      render json: result, status: :unprocessable_entity
    when :concurrency_conflict
      render json: result, status: :conflict
    else
      render json: result, status: :internal_server_error
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def transaction_params
    params.require(:transaction).permit(:amount_cents, :currency, :transaction_type, :idempotency_key, :campaign_id, :dest_owner_type, :dest_owner_id, metadata: {})
  end

  def normalize_owner_type(value)
    value.to_s.downcase
  end
end
