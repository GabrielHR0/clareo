# Job deduplication concern.
# Prevents the same job from being enqueued multiple times.
#
# Uses Redis SETNX with a TTL to track in-flight jobs.
# For maximum reliability, jobs should also be idempotent at the
# business logic level (see IdempotencyService).
#
# Usage:
#   class MyJob
#     include Sidekiq::Job
#     include Sidekiq::UniqueJob
#     unique_for :until_executed, ttl: 3600
#
#     def perform(args)
#       # ...
#     end
#   end
#
# Strategies:
#   :until_executed  - Prevent duplicates while job is running (default)
#   :until_success   - Prevent re-enqueue until TTL expires after success
#   :while_queued    - Prevent duplicates only while still in the queue

module Sidekiq
  module UniqueJob
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def unique_for(strategy = :until_executed, ttl: 3600)
        @unique_strategy = strategy
        @unique_ttl = ttl
      end

      def unique_strategy
        @unique_strategy || :until_executed
      end

      def unique_ttl
        @unique_ttl || 3600
      end
    end

    def unique_key(*args)
      "sidekiq:unique:#{self.class.name}:#{args.hash}"
    end

    def around_perform(*args)
      strategy = self.class.unique_strategy
      key = unique_key(*args)
      ttl = self.class.unique_ttl

      $redis.with do |conn|
        case strategy
        when :until_executed
          # Allow if key doesn't exist or is expired
          acquired = conn.set(key, "executing", nx: true, ex: ttl)
          if acquired
            begin
              yield
            ensure
              conn.del(key)
            end
          else
            Rails.logger.info("#{self.class.name} skipped (already executing): #{args.first}")
          end

        when :until_success
          acquired = conn.set(key, "executing", nx: true, ex: ttl)
          if acquired
            begin
              yield
              conn.set(key, "completed", ex: ttl)
            rescue => e
              conn.del(key)
              raise e
            end
          else
            status = conn.get(key)
            if status == "completed"
              Rails.logger.info("#{self.class.name} skipped (already completed): #{args.first}")
            else
              Rails.logger.info("#{self.class.name} skipped (already executing): #{args.first}")
            end
          end

        when :while_queued
          # Only prevent if the key exists (implies job is queued or running)
          if conn.exists(key)
            Rails.logger.info("#{self.class.name} skipped (already queued): #{args.first}")
          else
            conn.setex(key, ttl, "queued")
            begin
              yield
            ensure
              conn.del(key)
            end
          end
        end
      end
    end
  end
end
