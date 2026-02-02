# frozen_string_literal: true

require "net/http"
require "json"

# 以「參考人臉圖片 URL」＋「英文 Prompt」呼叫 Replicate InstantID Photorealistic，
# 生成保留臉部特徵的擬真圖（25 歲職業照等）。金鑰來自 ApiKeys.replicate_token。
class InstantIdService
  API_BASE = "https://api.replicate.com/v1"
  # 社群模型需用完整 version hash（見 https://replicate.com/grandlineai/instant-id-photorealistic/versions）
  MODEL_VERSION = "03914a0c3326bf44383d0cd84b06822618af879229ce5d1d53bef38d93b68279"
  PREFER_WAIT = 60
  READ_TIMEOUT = 85

  class Error < StandardError; end
  class MissingApiKey < Error; end
  class ApiError < Error; end
  class PredictionFailed < Error; end

  # 降低身份鎖定強度，讓 prompt（長大、職業）更明顯；0.3 較易有「30 歲長大」感，0.5+ 較像原臉
  DEFAULT_IP_ADAPTER_SCALE = 0.35
  # 負向提示：強烈排除孩童／青少年臉，讓模型傾向約 30 歲成人樣貌
  DEFAULT_NEGATIVE_PROMPT = "child, baby face, toddler, teen, adolescent, young child, kid, childish face, juvenile, baby fat, round child face, pre-teen"

  # @param image_url [String] 參考人臉圖片的 HTTPS URL（自拍照等）
  # @param prompt [String] 英文繪圖用 Prompt（例如來自 GeminiService.prompt_for_photorealistic_career）
  # @param ip_adapter_scale [Float, nil] 身份鎖定強度，愈低愈偏 prompt（長大）；nil 用預設 0.45
  # @param negative_prompt [String, nil] 負向提示；nil 用預設排除孩童臉
  # @return [String] 生成圖片的 HTTPS URL
  def self.generate(image_url:, prompt:, ip_adapter_scale: nil, negative_prompt: nil)
    new(image_url: image_url, prompt: prompt, ip_adapter_scale: ip_adapter_scale, negative_prompt: negative_prompt).generate
  end

  def initialize(image_url:, prompt:, ip_adapter_scale: nil, negative_prompt: nil)
    @image_url = image_url.to_s.strip
    @prompt = prompt.to_s.strip
    @ip_adapter_scale = ip_adapter_scale.nil? ? DEFAULT_IP_ADAPTER_SCALE : ip_adapter_scale.to_f
    @negative_prompt = negative_prompt.to_s.strip.presence || DEFAULT_NEGATIVE_PROMPT
  end

  def generate
    token = ApiKeys.replicate_token
    raise MissingApiKey, "REPLICATE_API_TOKEN 未設定（請檢查 .env 或 credentials）" if token.blank?
    raise ApiError, "image_url 不可為空" if @image_url.blank?
    raise ApiError, "prompt 不可為空" if @prompt.blank?

    # 降低身份鎖定（ip_adapter_scale）＋負向提示（排除孩童臉），讓「長大」效果更明顯
    input = {
      image: @image_url,
      prompt: @prompt
    }
    input[:negative_prompt] = @negative_prompt if @negative_prompt.present?
    input[:ip_adapter_scale] = @ip_adapter_scale if @ip_adapter_scale.between?(0.01, 2.0)
    # 若 grandlineai 模型不支援上述參數會回 422，可改為只送 image + prompt 或查該模型實際參數名

    body = {
      version: model_version_for_create,
      input: input
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
      raise ApiError, "Replicate API 錯誤: #{res.code} #{res.message} - #{res.body[0, 500]}"
    end

    data = JSON.parse(res.body)
    status = data["status"]
    output = data["output"]

    if status == "starting" || status == "processing"
      output = poll_until_done(data["id"], token)
    end

    image_url = extract_image_url(output, data)
    raise PredictionFailed, "Replicate 未回傳圖片 URL（status: #{status}）" if image_url.blank?

    image_url
  end

  private

  def model_version_for_create
    MODEL_VERSION
  end

  def poll_until_done(prediction_id, token)
    get_uri = URI("#{API_BASE}/predictions/#{prediction_id}")
    max_attempts = 45
    interval = 2

    max_attempts.times do
      get_req = Net::HTTP::Get.new(get_uri)
      get_req["Authorization"] = "Bearer #{token}"
      get_res = Net::HTTP.start(get_uri.host, get_uri.port, use_ssl: true, read_timeout: 20) { |h| h.request(get_req) }
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
