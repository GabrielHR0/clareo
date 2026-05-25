namespace :kafka do
  desc "Create Kafka topics required by Clareo"
  task create_topics: :environment do
    brokers = ENV["KAFKA_BROKERS"].to_s
    if brokers.empty?
      puts "KAFKA_BROKERS is not configured; skipping topic creation"
      next
    end

    begin
      require "kafka"
      # The `kafka` gem normally exposes `Kafka.new(...)`. In some environments
      # a `Kafka` module may be defined by other code which breaks `new`.
      # Try several fallbacks to instantiate a client.
      kafka = if Kafka.respond_to?(:new)
                Kafka.new(seed_brokers: brokers.split(","))
              elsif Kafka.const_defined?("Client") && Kafka::Client.respond_to?(:new)
                Kafka::Client.new(seed_brokers: brokers.split(","))
              else
                raise "Unable to instantiate Kafka client (Kafka constant present but no suitable constructor)"
              end

      topics = %w[
        donations.created
        donations.recurring.processed
        transactions.posted
        wallets.balance_changed
        floating.interest_applied
        credit.line_used
        credit.repayment
        audit.events
      ]

      topics.each do |topic|
        begin
          kafka.create_topic(topic)
          puts "Created topic: #{topic}"
        rescue Kafka::TopicAlreadyExists
          puts "Topic already exists: #{topic}"
        end
      end
    rescue LoadError
      puts "Kafka gem not available; install dependencies first"
    rescue => e
      puts "Error instantiating Kafka client: #{e.class} #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end
