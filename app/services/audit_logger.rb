require_relative "../repositories/audit_events_repository"
require_relative "../../lib/kafka_producer"

module AuditLogger
  extend self

  # Log an audit event both to Cassandra and to Kafka (topic audit.events)
  def log(owner_type:, owner_id:, event_type:, payload: {})
    # Persist to Cassandra (repo will coerce payload to strings)
    AuditEventsRepository.insert(
      owner_type: owner_type,
      owner_id: owner_id,
      event_type: event_type,
      payload: payload
    )

    # Publish to Kafka for downstream consumers
    KafkaProducer.publish('audit.events', { owner_type: owner_type.to_s, owner_id: owner_id.to_s, event_type: event_type, payload: payload })
  rescue => e
    Rails.logger.error("AuditLogger failed: #{e.message}")
    false
  end
end
