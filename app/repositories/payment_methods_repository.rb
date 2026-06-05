class PaymentMethodsRepository
  INSERT_CQL = "INSERT INTO clareo.payment_methods (owner_type, owner_id, method_id, method_type, details, is_default, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
  SELECT_DEFAULT_CQL = "SELECT * FROM clareo.payment_methods WHERE owner_type = ? AND owner_id = ? AND is_default = true ALLOW FILTERING"

  def initialize(session = CassandraClient.session_without_keyspace)
    @session = session
  end

  def create(owner_type:, owner_id:, method_type:, details:, is_default: false)
    method_id = SecureRandom.uuid
    @session.execute(INSERT_CQL, arguments: [owner_type.to_s, normalize_uuid(owner_id), normalize_uuid(method_id), method_type.to_s, details, is_default, Time.now])
    { method_id: method_id, owner_type: owner_type, owner_id: owner_id, method_type: method_type, details: details, is_default: is_default }
  end

  def find_default(owner_type, owner_id)
    rows = @session.execute(SELECT_DEFAULT_CQL, arguments: [owner_type.to_s, normalize_uuid(owner_id)])
    row = rows.first
    return nil unless row
    { method_id: row['method_id'], method_type: row['method_type'], details: row['details'] }
  end

  private

  def normalize_uuid(v)
    return v if v.is_a?(Cassandra::Uuid)
    Cassandra::Uuid.new(v) if v
  end
end
