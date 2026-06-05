class RecurringDonationService
  def self.create(attrs)
    attrs[:recurring_id] ||= SecureRandom.uuid

    org_id = attrs[:organization_id]
    contrib_id = attrs[:contributor_id]

    raise "organization_id is required" unless org_id
    raise "contributor_id is required" unless contrib_id

    org = OrganizationsRepository.find(org_id)
    raise "Organization not found" unless org

    id = RecurringDonationsRepository.create(attrs)
    id
  end
end
