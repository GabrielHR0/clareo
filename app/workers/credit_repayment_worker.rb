class CreditRepaymentWorker
  include Sidekiq::Worker

  # This worker is a skeleton to be scheduled to run periodic repayment processing
  # For now it just logs and would call domain-specific processors
  def perform
    Rails.logger.info("CreditRepaymentWorker: starting repayment run")

    # Iterate all credit lines and attempt to apply recent donations for each organization
    credits = CreditLinesRepository.all
    org_ids = credits.map { |c| c[:organization_id] }.uniq

    org_ids.each do |org_id|
      begin
        # fetch recent transactions for organization
        txs = TransactionsByOwnerRepository.find_by_owner(org_id, "organization", 200)
        txs.each do |tx|
          next unless tx[:transaction_type] == "credit"
          meta = tx[:metadata] || {}
          apply_flag = meta["apply_to_credit"] || meta[:apply_to_credit]
          applied_flag = meta["applied_to_credit"]
          next unless apply_flag && !applied_flag

          amount = tx[:amount_cents].to_i
          Rails.logger.info("CreditRepaymentWorker: applying donation tx=#{tx[:transaction_id]} org=#{org_id} amount=#{amount}")
          res = CreditService.apply_payment_from_donation(organization_id: org_id, amount_cents: amount)

          # mark transaction as applied to avoid duplicates
          new_meta = (meta || {}).merge("applied_to_credit" => true)
          TransactionsByOwnerRepository.update_metadata("organization", org_id, tx[:transaction_id], new_meta)
          Rails.logger.info("CreditRepaymentWorker: applied result=#{res}")
        end
      rescue => e
        Rails.logger.error("CreditRepaymentWorker error for org=#{org_id}: #{e.message}")
      end
    end

    Rails.logger.info("CreditRepaymentWorker: finished repayment run")
  end
end
