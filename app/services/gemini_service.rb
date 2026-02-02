# frozen_string_literal: true

require "net/http"
require "json"

# 將孩童的夢想描述轉成給 Replicate 繪圖用的英文 Prompt。
# 使用 Google Gemini API；金鑰來自 ApiKeys.gemini_api_key（.env 或 credentials）。
class GeminiService
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
  # 若 429 配額錯誤可改為 "gemini-1.5-flash" 或 "gemini-1.5-flash-8b"（免費額度較寬）
  MODEL = "gemini-1.5-flash"

  class Error < StandardError; end
  class MissingApiKey < Error; end
  class ApiError < Error; end

  # @param dream [String] 夢想描述，例如「我想當醫生」「太空人」
  # @param gender [String, nil] 可選，例如 "男"、"女"
  # @param age [String, Integer, nil] 可選，例如 "8"、8
  # @return [String] 英文繪圖用 Prompt（單一段落，無前後空白與換行）
  def self.prompt_for_image(dream:, gender: nil, age: nil)
    new(dream: dream, gender: gender, age: age).prompt_for_image
  end

  def initialize(dream:, gender: nil, age: nil)
    @dream = dream.to_s.strip
    @gender = gender.to_s.strip.presence
    @age = age.to_s.strip.presence
  end

  def prompt_for_image
    key = ApiKeys.gemini_api_key
    raise MissingApiKey, "GEMINI_API_KEY 未設定（請檢查 .env 或 credentials）" if key.blank?

    body = {
      contents: [
        {
          parts: [
            { text: system_and_user_prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.8,
        maxOutputTokens: 512,
        responseMimeType: "text/plain"
      }
    }

    uri = URI("#{BASE_URL}/models/#{MODEL}:generateContent")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["x-goog-api-key"] = key
    req.body = body.to_json

    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      raise ApiError, "Gemini API 錯誤: #{res.code} #{res.message} - #{res.body[0, 500]}"
    end

    data = JSON.parse(res.body)
    text = data.dig("candidates", 0, "content", "parts", 0, "text")
    raise ApiError, "Gemini 未回傳文字" if text.blank?

    text.strip
  end

  private

  def system_and_user_prompt
    <<~PROMPT.strip
      你是一位專門為「孩童夢想成真」照片生成撰寫繪圖指令的專家。請根據以下描述，產出「一段」英文的 image generation prompt，給 AI 繪圖模型（例如 Flux、SDXL）使用。

      要求：
      - 只輸出「一段」英文描述，不要編號、不要分點、不要標題。
      - 描述中要包含：人物（亞洲孩童、依性別與年齡）、服裝與情境（對應夢想職業）、明亮溫暖的氛圍、風格可寫「Pixar style」或「photorealistic」。
      - 長度約 1～3 句，用逗號分隔細節即可。
      - 不要輸出任何中文或說明，只輸出這一段英文。

      夢想描述：#{@dream}
      #{@gender.present? ? "性別：#{@gender}" : ""}
      #{@age.present? ? "年齡：#{@age}" : ""}
    PROMPT
  end
end
