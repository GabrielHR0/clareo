require "securerandom"

module CampaignsByTagRepository
  extend self

  INSERT_CQL = <<~CQL
    INSERT INTO clareo.campaigns_by_tag (tag, campaign_id, organization_id, name, cover_image, cover_color, goal_cents, raised_cents, held_cents, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  CQL

  LIST_CQL = "SELECT * FROM clareo.campaigns_by_tag WHERE tag = ?"
  LIST_ALL_CQL = "SELECT * FROM clareo.campaigns_by_tag ALLOW FILTERING"
  DELETE_CQL = "DELETE FROM clareo.campaigns_by_tag WHERE tag = ? AND campaign_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @list   = CassandraClient.session.prepare(LIST_CQL)
    @list_all = CassandraClient.session.prepare(LIST_ALL_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def insert(tag:, campaign_id:, organization_id:, name:, cover_image: nil, cover_color: nil, goal_cents: 0, raised_cents: 0, held_cents: 0, status: "draft")
    prepare!
    CassandraClient.session.execute(@insert, arguments: [
      tag,
      normalize_uuid(campaign_id),
      normalize_uuid(organization_id),
      name,
      cover_image,
      cover_color,
      goal_cents,
      raised_cents,
      held_cents,
      status
    ], consistency: :quorum)
  end

  def list_by_tag(tag)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [tag], consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def delete(tag:, campaign_id:)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [tag, normalize_uuid(campaign_id)], consistency: :quorum)
  end

  def list_all
    prepare!
    rows = CassandraClient.session.execute(@list_all, consistency: :quorum)
    rows.map { |r| row_to_hash(r) }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value || SecureRandom.uuid)
  end

  private

  def row_to_hash(row)
    {
      tag: row["tag"],
      campaign_id: row["campaign_id"].to_s,
      organization_id: row["organization_id"].to_s,
      name: row["name"],
      cover_image: row["cover_image"],
      cover_color: row["cover_color"],
      goal_cents: row["goal_cents"],
      raised_cents: row["raised_cents"],
      held_cents: row["held_cents"] || 0,
      status: row["status"]
    }
  end
end
