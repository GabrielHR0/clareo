module PaymentMethodsRepository
  extend self

  INSERT_CQL = "INSERT INTO clareo.payment_methods (owner_type, owner_id, method_id, method_type, details, is_default, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
  SELECT_DEFAULT_CQL = "SELECT * FROM clareo.payment_methods WHERE owner_type = ? AND owner_id = ? AND is_default = true ALLOW FILTERING"
  LIST_CQL = "SELECT * FROM clareo.payment_methods WHERE owner_type = ? AND owner_id = ?"
  DELETE_CQL = "DELETE FROM clareo.payment_methods WHERE owner_type = ? AND owner_id = ? AND method_id = ?"

  def prepare!
    return if @prepared
    @insert = CassandraClient.session.prepare(INSERT_CQL)
    @get_default = CassandraClient.session.prepare(SELECT_DEFAULT_CQL)
    @list = CassandraClient.session.prepare(LIST_CQL)
    @delete = CassandraClient.session.prepare(DELETE_CQL)
    @prepared = true
  end

  def create(owner_type:, owner_id:, method_type:, details:, is_default: false)
    prepare!
    method_id = Cassandra::Uuid.new(SecureRandom.uuid)
    CassandraClient.session.execute(@insert, arguments: [
      owner_type.to_s, normalize_uuid(owner_id), method_id,
      method_type.to_s, details, is_default, Time.now
    ], consistency: :quorum)
    { method_id: method_id.to_s, owner_type: owner_type, owner_id: owner_id, method_type: method_type, details: details, is_default: is_default }
  end

  def list(owner_type, owner_id)
    prepare!
    rows = CassandraClient.session.execute(@list, arguments: [owner_type.to_s, normalize_uuid(owner_id)], consistency: :quorum)
    rows.map do |row|
      {
        method_id: row["method_id"].to_s,
        method_type: row["method_type"],
        details: row["details"],
        is_default: row["is_default"],
        created_at: row["created_at"]
      }
    end
  end

  def delete(owner_type, owner_id, method_id)
    prepare!
    CassandraClient.session.execute(@delete, arguments: [owner_type.to_s, normalize_uuid(owner_id), normalize_uuid(method_id)], consistency: :quorum)
  end

  def find_default(owner_type, owner_id)
    prepare!
    rows = CassandraClient.session.execute(@get_default, arguments: [
      owner_type.to_s, normalize_uuid(owner_id)
    ], consistency: :quorum)
    row = rows.first
    return nil unless row
    { method_id: row["method_id"].to_s, method_type: row["method_type"], details: row["details"] }
  end

  def normalize_uuid(value)
    return value if value.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(value) if value
  end
end
