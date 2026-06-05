require "securerandom"

module CampaignsByIdRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.campaigns_by_id (campaign_id, organization_id, name)
    VALUES (?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.campaigns_by_id WHERE campaign_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @prepared = true
  end

  def insert(attrs)
    prepare!
    CassandraClient.session.execute(@insert, arguments: [
      normalize_uuid(attrs[:campaign_id]),
      normalize_uuid(attrs[:organization_id]),
      attrs[:name]
    ], consistency: :quorum)
  end

  def find(campaign_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(campaign_id)
    ], consistency: :quorum).first
    row && { campaign_id: row["campaign_id"].to_s, organization_id: row["organization_id"].to_s, name: row["name"] }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end
end
