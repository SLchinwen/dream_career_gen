# frozen_string_literal: true

# API 金鑰讀取：優先使用環境變數，沒有則從 Rails credentials 讀取。
# 本機開發可用 bin/rails credentials:edit 寫入；GCP Cloud Run 用「變數與密碼」設定環境變數。
# 勿將金鑰明文提交至 Git。

module ApiKeys
  def self.replicate_token
    ENV.fetch("REPLICATE_API_TOKEN") { Rails.application.credentials.dig(:replicate, :token) }
  end

  def self.gemini_api_key
    ENV.fetch("GEMINI_API_KEY") { Rails.application.credentials.dig(:gemini, :api_key) }
  end
end
