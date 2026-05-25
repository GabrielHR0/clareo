require "json"

module KafkaProducer
  extend self

  def publish(topic, payload)
    message = payload.is_a?(String) ? payload : JSON.generate(payload)
    brokers = ENV["KAFKA_BROKERS"]
    if brokers.to_s.strip.empty?
      Rails.logger.info("KafkaProducer: no brokers configured, skipping publish to #{topic}: #{message}")
      return false
    end

    begin
      require "kafka"
      kafka = Kafka.new(seed_brokers: brokers.split(","))
      producer = kafka.async_producer(delivery_interval: 1)
      producer.produce(message, topic: topic)
      producer.deliver_messages
      Rails.logger.info("KafkaProducer: published to #{topic}")
      true
    rescue LoadError
      Rails.logger.warn("Kafka gem not installed; skipping publish to #{topic}")
      false
    rescue => e
      Rails.logger.error("KafkaProducer error publishing to #{topic}: #{e.message}")
      false
    end
  end
end
