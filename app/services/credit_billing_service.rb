class CreditBillingService
  def self.generate_monthly_bills(organization_id)
    credit_lines = CreditLinesRepository.find_by_organization(normalize_uuid(organization_id))
    bills = []

    credit_lines.each do |cl|
      next if cl[:status] != "active" || (cl[:used_cents] || 0) <= 0

      bill_id = SecureRandom.uuid
      next_due = Date.today.next_month
      amount = cl[:used_cents]

      CreditBillsRepository.create(
        organization_id: organization_id,
        bill_id: bill_id,
        credit_id: cl[:credit_id],
        due_date: next_due,
        amount_cents: amount,
        paid_cents: 0,
        status: "pending",
        created_at: Time.now,
        paid_at: nil
      )

      bills << { bill_id: bill_id, amount_cents: amount, due_date: next_due }
    end

    bills
  end

  def self.pay_bill(organization_id, bill_id, amount_cents)
    bill = CreditBillsRepository.find(organization_id, bill_id)
    return { status: :not_found } unless bill
    return { status: :already_paid } if bill[:status] == "paid"

    paid = [amount_cents, bill[:amount_cents] - bill[:paid_cents]].min
    result = CreditService.repay_credit(credit_id: bill[:credit_id], amount_cents: paid)
    return result if result[:status] != :ok

    new_paid = bill[:paid_cents] + paid
    new_status = new_paid >= bill[:amount_cents] ? "paid" : "partial"

    update_cql = "UPDATE clareo.credit_bills SET paid_cents = ?, status = ?, paid_at = ? WHERE organization_id = ? AND bill_id = ?"
    CassandraClient.session.execute(
      CassandraClient.session.prepare(update_cql),
      arguments: [new_paid, new_status, new_status == "paid" ? Time.now : nil, normalize_uuid(organization_id), normalize_uuid(bill_id)]
    )

    { status: :ok, bill_id: bill_id, paid: paid, new_status: new_status }
  end

  def self.normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value)
  rescue ArgumentError
    nil
  end
end
