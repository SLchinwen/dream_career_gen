# frozen_string_literal: true

require "net/http"
require "json"

# 將英文繪圖 Prompt 送給 Replicate（Flux）產生圖片，回傳圖片 URL。
# 金鑰來自 ApiKeys.replicate_token（.env 或 credentials）。
class ReplicateService
  API_BASE = "https://api.replicate.com/v1"
  # 官方模型：Flux Schnell（文字→圖，速度快）；可改為 stability-ai/sdxl 等
  MODEL = "black-forest-labs/flux-schnell"
  WAIT_SECONDS = 60

  class Error < StandardError; end
  class MissingApiKey < Error; end
  class ApiError < Error; end
  class PredictionFailed < Error; end

  # @param prompt [String] 英文繪圖用 Prompt（例如來自 GeminiService）
  # @return [String] 生成圖片的 HTTPS URL
  def self.generate_image(prompt:)
    new(prompt: prompt).generate_image
  end

  def initialize(prompt:)
    @prompt = prompt.to_s.strip
  end

  def generate_image
    token = ApiKeys.replicate_token
    raise MissingApiKey, "REPLICATE_API_TOKEN 未設定（請檢查 .env 或 credentials）" if token.blank?
    raise ApiError, "Prompt 不可為空" if @prompt.blank?

    # 建立 prediction（同步等待最多 WAIT_SECONDS 秒）
    body = {
      version: model_version_for_create,
      input: { prompt: @prompt }
    }

    uri = URI("#{API_BASE}/predictions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = WAIT_SECONDS + 15

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{token}"
    req["Prefer"] = "wait=#{WAIT_SECONDS}"
    req.body = body.to_json

    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      raise ApiError, "Replicate API 錯誤: #{res.code} #{res.message} - #{res.body[0, 500]}"
    end

    data = JSON.parse(res.body)
    status = data["status"]
    output = data["output"]

    # 若尚未完成，輪詢一次（可再擴充為迴圈輪詢）
    if status == "starting" || status == "processing"
      id = data["id"]
      output = poll_until_done(id, token)
    end

    image_url = extract_image_url(output, data)
    raise PredictionFailed, "Replicate 未回傳圖片 URL（status: #{status}）" if image_url.blank?

    image_url
  end

  private

  # 官方模型用 owner/name；非官方需 version ID，此處用 MODEL 當 version 傳（API 接受 owner/name）
  def model_version_for_create
    MODEL
  end

  def poll_until_done(prediction_id, token)
    get_uri = URI("#{API_BASE}/predictions/#{prediction_id}")
    max_attempts = 30
    interval = 2

    max_attempts.times do
      get_req = Net::HTTP::Get.new(get_uri)
      get_req["Authorization"] = "Bearer #{token}"
      get_res = Net::HTTP.start(get_uri.host, get_uri.port, use_ssl: true, read_timeout: 15) { |h| h.request(get_req) }
      return nil unless get_res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(get_res.body)
      status = data["status"]
      return data["output"] if status == "succeeded"
      raise PredictionFailed, "Replicate 預測失敗: #{data['error']}" if status == "failed"

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
