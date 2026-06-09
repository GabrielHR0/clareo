class FinanceController < ApplicationController
  def show
    owner_type = params[:owner_type] || "organization"
    owner_id = params[:owner_id]

    return render json: { error: "owner_id required" }, status: :bad_request unless owner_id

    wallet = WalletsRepository.find(owner_id, owner_type) || {}
    credit_lines = if owner_type == "organization"
      CreditLinesRepository.find_by_organization(owner_id)
    else
      []
    end
    bills = if owner_type == "organization"
      CreditBillsRepository.list(owner_id)
    else
      []
    end
    payment_methods = PaymentMethodsRepository.list(owner_type, owner_id)
    transactions = TransactionsByOwnerRepository.find_by_owner(owner_id, owner_type, 100)

    enriched_tx = transactions.map do |tx|
      camp_id = tx[:campaign_id] || tx.dig(:metadata, "campaign_id")
      if camp_id.present? && camp_id != "00000000-0000-0000-0000-000000000000" && owner_type == "organization"
        campaign = CampaignsRepository.find(owner_id, camp_id) rescue nil
        tx[:campaign_name] = campaign[:name] if campaign
      end
      tx
    end

    render json: {
      wallet: wallet,
      credit_lines: credit_lines,
      bills: bills,
      payment_methods: payment_methods,
      transactions: enriched_tx
    }
  end
end
