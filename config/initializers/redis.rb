# frozen_string_literal: true

# RID3510 聊天 10 輪對話儲存。未設定 REDIS_URL 時不連線，應用可優雅降級（不持久化對話）。
Rails.application.config.after_initialize do
  redis_url = ENV["REDIS_URL"].presence
  if redis_url.present?
    Rails.application.config.rid3510_redis = Redis.new(url: redis_url)
  else
    Rails.application.config.rid3510_redis = nil
  end
rescue StandardError => e
  Rails.logger.warn("[Rid3510] Redis 連線略過: #{e.message}")
  Rails.application.config.rid3510_redis = nil
end
