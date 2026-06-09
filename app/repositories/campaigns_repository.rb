require "securerandom"
require "time"

module CampaignsRepository
  extend self

  CREATE_CQL = <<~CQL
    INSERT INTO clareo.campaigns (organization_id, campaign_id, name, description, goal_cents, raised_cents, held_cents, status, starts_at, ends_at, cover_image, cover_color, tags, metadata, created_at, updated_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  GET_CQL = "SELECT * FROM clareo.campaigns WHERE organization_id = ? AND campaign_id = ?"
  LIST_CQL = "SELECT * FROM clareo.campaigns WHERE organization_id = ? LIMIT ?"
  UPDATE_CQL = <<~CQL
    UPDATE clareo.campaigns SET
      name = ?, description = ?, goal_cents = ?, raised_cents = ?, held_cents = ?,
      status = ?, starts_at = ?, ends_at = ?, cover_image = ?, cover_color = ?,
      tags = ?, metadata = ?, updated_at = ?
    WHERE organization_id = ? AND campaign_id = ?
  CQL

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(CREATE_CQL)
    @get    = CassandraClient.session.prepare(GET_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @update = CassandraClient.session.prepare(UPDATE_CQL)
    @prepared = true
  end

  def create(attrs)
    prepare!
    id = normalize_uuid(attrs[:campaign_id])
    org_id = normalize_uuid(attrs[:organization_id])
    now = Time.now.utc
    status = attrs[:status] || "draft"
    tags = attrs[:tags]
    tags = tags.is_a?(Array) ? tags.to_set : (tags.is_a?(Set) ? tags : Set.new)

    created_at = attrs[:created_at]
    created_at = created_at.is_a?(String) ? Time.iso8601(created_at) : (created_at || now)

    CassandraClient.session.execute(@insert, arguments:
      [
        org_id,
        id,
        attrs[:name],
        attrs[:description],
        (attrs[:goal_cents] || 0).to_i,
        (attrs[:raised_cents] || 0).to_i,
        (attrs[:held_cents] || 0).to_i,
        status,
        normalize_timestamp(attrs[:starts_at]),
        normalize_timestamp(attrs[:ends_at]),
        attrs[:cover_image],
        attrs[:cover_color],
        tags,
        attrs[:metadata] || {},
        created_at,
        now
      ], consistency: :quorum)

    CampaignsByIdRepository.insert(campaign_id: id, organization_id: org_id, name: attrs[:name])

    tags.each do |tag|
      CampaignsByTagRepository.insert(tag: tag, campaign_id: id, organization_id: org_id, name: attrs[:name],
        cover_image: attrs[:cover_image], cover_color: attrs[:cover_color],
        goal_cents: (attrs[:goal_cents] || 0).to_i, raised_cents: (attrs[:raised_cents] || 0).to_i,
        held_cents: (attrs[:held_cents] || 0).to_i, status: status)
    end

    { campaign_id: id.to_s, organization_id: org_id.to_s }
  end

  def find(org_id, campaign_id)
    prepare!
    row = CassandraClient.session.execute(@get, arguments: [
      normalize_uuid(org_id),
      normalize_uuid(campaign_id)
    ], consistency: :quorum).first
    row && row_to_hash(row)
  end

  def update(attrs)
    prepare!
    CassandraClient.session.execute(@update, arguments: [
      attrs[:name],
      attrs[:description],
      (attrs[:goal_cents] || 0).to_i,
      (attrs[:raised_cents] || 0).to_i,
      (attrs[:held_cents] || 0).to_i,
      attrs[:status] || "draft",
      normalize_timestamp(attrs[:starts_at]),
      normalize_timestamp(attrs[:ends_at]),
      attrs[:cover_image],
      attrs[:cover_color],
      attrs[:tags].is_a?(Array) ? attrs[:tags].to_set : (attrs[:tags].is_a?(Set) ? attrs[:tags] : Set.new),
      attrs[:metadata] || {},
      Time.now.utc,
      normalize_uuid(attrs[:organization_id]),
      normalize_uuid(attrs[:campaign_id]),
    ], consistency: :quorum)

    tags = attrs[:tags]
    tags = tags.is_a?(Array) ? tags.to_set : (tags.is_a?(Set) ? tags : Set.new)
    tags.each do |tag|
      CampaignsByTagRepository.insert(tag: tag, campaign_id: attrs[:campaign_id],
        organization_id: attrs[:organization_id], name: attrs[:name],
        cover_image: attrs[:cover_image], cover_color: attrs[:cover_color],
        goal_cents: (attrs[:goal_cents] || 0).to_i,
        raised_cents: (attrs[:raised_cents] || 0).to_i,
        held_cents: (attrs[:held_cents] || 0).to_i,
        status: attrs[:status] || "draft")
    end
  end

  def list(org_id, limit = 100)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [
      normalize_uuid(org_id), limit
    ], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  def normalize_timestamp(value)
    return nil if value.nil?
    return value if value.is_a?(Time)
    value.is_a?(String) ? Time.iso8601(value) : value
  end

  private

  def row_to_hash(row)
    {
      organization_id: row["organization_id"].to_s,
      campaign_id: row["campaign_id"].to_s,
      name: row["name"],
      description: row["description"],
      goal_cents: row["goal_cents"],
      raised_cents: row["raised_cents"],
      held_cents: row["held_cents"] || 0,
      status: row["status"],
      starts_at: row["starts_at"],
      ends_at: row["ends_at"],
      cover_image: row["cover_image"],
      cover_color: row["cover_color"],
      tags: row["tags"]&.to_a || [],
      metadata: row["metadata"],
      created_at: row["created_at"],
      updated_at: row["updated_at"]
    }
  end
end
