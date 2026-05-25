class TransactionsController < ApplicationController
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
end
