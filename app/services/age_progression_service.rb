# frozen_string_literal: true

require "net/http"
require "json"

# 第一階段：用 Replicate SAM（Style-based Age Manipulation）把臉「長大」到目標年齡，
# 回傳長大後圖片的 URL，供後續 InstantID 職業照使用。
# 金鑰來自 ApiKeys.replicate_token。
class AgeProgressionService
  API_BASE = "https://api.replicate.com/v1"
  # yuval-alaluf/sam：年齡變化，target_age 0–100，保留身份
  # https://replicate.com/yuval-alaluf/sam/versions
  MODEL_VERSION = "9222a21c181b707209ef12b5e0d7e94c994b58f01c7b2fec075d2e892362f13c"
  TARGET_AGE = "30"
  PREFER_WAIT = 60
  READ_TIMEOUT = 90

  class Error < StandardError; end
  class MissingApiKey < Error; end
  class ApiError < Error; end
  class PredictionFailed < Error; end

  # @param image_url [String] 人臉圖片的 HTTPS URL 或 data URL
  # @param target_age [String] 目標年齡，預設 "30"
  # @return [String] 長大後圖片的 HTTPS URL；失敗則 raise
  def self.age_to(image_url:, target_age: TARGET_AGE)
    new(image_url: image_url, target_age: target_age).run
  end

  def initialize(image_url:, target_age: TARGET_AGE)
    @image_url = image_url.to_s.strip
    @target_age = target_age.to_s.strip.presence || TARGET_AGE
  end

  def run
    token = ApiKeys.replicate_token
    raise MissingApiKey, "REPLICATE_API_TOKEN 未設定（請檢查 .env 或 credentials）" if token.blank?
    raise ApiError, "image_url 不可為空" if @image_url.blank?

    body = {
      version: MODEL_VERSION,
      input: {
        image: @image_url,
        target_age: @target_age
      }
    }

    uri = URI("#{API_BASE}/predictions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = READ_TIMEOUT

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{token}"
    req["Prefer"] = "wait=#{PREFER_WAIT}"
    req.body = body.to_json

    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      raise ApiError, "Replicate SAM API 錯誤: #{res.code} #{res.message} - #{res.body[0, 500]}"
    end

    data = JSON.parse(res.body)
    status = data["status"]
    output = data["output"]

    if status == "starting" || status == "processing"
      output = poll_until_done(data["id"], token)
    end

    image_url = extract_image_url(output, data)
    raise PredictionFailed, "SAM 未回傳圖片 URL（status: #{status}）" if image_url.blank?

    image_url
  end

  private

  def poll_until_done(prediction_id, token)
    get_uri = URI("#{API_BASE}/predictions/#{prediction_id}")
    max_attempts = 30
    interval = 2

    max_attempts.times do
      get_req = Net::HTTP::Get.new(get_uri)
      get_req["Authorization"] = "Bearer #{token}"
      get_res = Net::HTTP.start(get_uri.host, get_uri.port, use_ssl: true, read_timeout: 20) { |h| h.request(get_req) }
      return nil unless get_res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(get_res.body)
      status = data["status"]
      return data["output"] if status == "succeeded"
      raise PredictionFailed, "SAM 預測失敗: #{data['error']}" if status == "failed"

      sleep interval
    end

    nil
  end

  def extract_image_url(output, data)
    return output if output.is_a?(String) && output.start_with?("http")
    return output.first if output.is_a?(Array) && output.first.is_a?(String) && output.first.start_with?("http")
    return output["url"] if output.is_a?(Hash) && output["url"].to_s.start_with?("http")

    nil
  end
end
