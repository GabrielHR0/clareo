# Sidekiq server middleware for job deduplication.
# This runs in the Sidekiq process as middleware, wrapping every job execution.
#
# Pattern: At-least-once delivery with idempotent processing.
# Sidekiq guarantees at-least-once — this middleware adds at-most-once
# semantics within the deduplication window via Redis SETNX.
#
# For critical financial operations, the business logic itself must also
# be idempotent (see IdempotencyService), because the middleware
# cannot protect against crashes that happen AFTER the middleware
# releases the lock but BEFORE Sidekiq acknowledges completion.

module Sidekiq
  class JobDeduplicator
    DEDUP_PREFIX = "sidekiq:dedup:"

    def call(worker, job, queue)
      # Skip deduplication for scheduled/cron jobs
      if job["cron"] || job["at"]
        yield
        next
      end

      # Build dedup key from class name and arguments
      dedup_key = "#{DEDUP_PREFIX}#{job['class']}:#{Zlib.crc32(job['args'].to_json)}"

      $redis.with do |conn|
        # SET NX with 1-hour TTL
        acquired = conn.set(dedup_key, job['jid'], nx: true, ex: 3600)

        if acquired
          begin
            yield
          rescue => e
            # On failure, remove dedup key so the job can be retried
            conn.del(dedup_key)
            raise e
          end
        else
          existing_jid = conn.get(dedup_key)
          if existing_jid == job['jid']
            # Same job instance — allow it (retry/reenqueue)
            yield
          else
            Rails.logger.info "Deduplicated #{job['class']} (already processed): #{job['args'].first}"
          end
        end
      end
    end
  end
end
