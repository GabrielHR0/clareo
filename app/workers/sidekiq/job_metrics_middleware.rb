# Sidekiq server middleware for job execution metrics.
# Records job duration, success/failure counts, and queue latency in Redis.
# Useful for monitoring across multiple instances.

module Sidekiq
  class JobMetricsMiddleware
    METRICS_PREFIX = "sidekiq:metrics:"

    def call(worker, job, queue)
      start_time = Time.now
      queue_latency = Time.now.to_f - (job["enqueued_at"] || start_time.to_f)

      yield

      duration = ((Time.now - start_time) * 1000).round
      record_metric(job["class"], "success", duration, queue_latency)
    rescue => e
      duration = ((Time.now - start_time) * 1000).round
      record_metric(job["class"], "failure", duration, queue_latency)
      raise e
    end

    private

    def record_metric(job_class, status, duration_ms, latency_s)
      now = Time.now.utc
      hour_key = now.strftime("%Y-%m-%d-%H")
      day_key = now.strftime("%Y-%m-%d")

      $redis.with do |conn|
        pipeline = conn.pipelined
        pipeline.hincrby("#{METRICS_PREFIX}#{job_class}:#{hour_key}", status, 1)
        pipeline.hincrby("#{METRICS_PREFIX}#{job_class}:#{day_key}", status, 1)
        pipeline.lpush("#{METRICS_PREFIX}#{job_class}:durations", duration_ms)
        pipeline.ltrim("#{METRICS_PREFIX}#{job_class}:durations", 0, 999)
        pipeline.lpush("#{METRICS_PREFIX}#{job_class}:latencies", latency_s)
        pipeline.ltrim("#{METRICS_PREFIX}#{job_class}:latencies", 0, 999)
        pipeline.expire("#{METRICS_PREFIX}#{job_class}:#{hour_key}", 72 * 3600)
        pipeline.expire("#{METRICS_PREFIX}#{job_class}:#{day_key}", 31 * 24 * 3600)
      end
    rescue Redis::BaseConnectionError
      # Metrics are non-critical — don't fail the job
    end
  end
end
