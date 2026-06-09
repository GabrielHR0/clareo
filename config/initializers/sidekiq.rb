require "sidekiq"
require "sidekiq/cron"

# Configure Sidekiq to use the same Redis instance.
# Sidekiq reads REDIS_URL by default, but we configure it explicitly.
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.server_middleware do |chain|
    chain.add Sidekiq::JobDeduplicator
    chain.add Sidekiq::JobMetricsMiddleware
  end

  config.on(:startup) do
    # Load cron jobs from config/sidekiq.yml
    schedule_file = Rails.root.join("config", "sidekiq.yml")
    if schedule_file.exist?
      schedule = YAML.safe_load(ERB.new(File.read(schedule_file)).result)
      if schedule && schedule["scheduler"]
        Sidekiq::Cron::Job.load_from_hash(schedule["scheduler"])
      end
    end

    Rails.logger.info "Sidekiq server started with #{config.options[:concurrency]} threads"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
