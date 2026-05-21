# frozen_string_literal: true

module TestLogger
  def test_log(message, level: :info)
    Rails.logger.public_send(level, "[spec] #{message}")
  end

  def test_log_json(message, payload, level: :info)
    json = payload.is_a?(String) ? payload : payload.to_json
    Rails.logger.public_send(level, "[spec] #{message} | payload=#{json}")
  end
end
