class CreditRequestService
  def self.request_credit(organization_id:, requested_cents:, annual_rate: nil)
    raise ArgumentError, "requested_cents must be positive" if requested_cents.to_i <= 0

    existing = CreditLinesRepository.find_by_organization(normalize_uuid(organization_id))
    active = existing.select { |cl| cl[:status] == "active" }

    if active.any?
      current = active.first
      new_limit = current[:limit_cents] + requested_cents
      new_available = (current[:available_cents] || 0) + requested_cents
      update_cql = "UPDATE clareo.credit_lines SET limit_cents = ?, available_cents = ? WHERE credit_id = ?"
      CassandraClient.session.execute(
        CassandraClient.session.prepare(update_cql),
        arguments: [new_limit, new_available, normalize_uuid(current[:credit_id])]
      )
      return { credit_id: current[:credit_id], limit_cents: new_limit, status: :approved, message: "Limite aumentado em #{format_cents(requested_cents)}" }
    end

    result = CreditService.create_line(
      organization_id: organization_id,
      limit_cents: requested_cents,
      annual_rate: annual_rate
    )

    { **result, status: :approved, message: "Crédito aprovado! Limite: #{format_cents(requested_cents)}" }
  end

  def self.format_cents(cents)
    "R$ #{cents.to_i / 100},#{(cents.to_i % 100).to_s.rjust(2, '0')}"
  end

  def self.normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value)
  rescue ArgumentError
    nil
  end
end
