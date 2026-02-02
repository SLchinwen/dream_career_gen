# frozen_string_literal: true

require "net/http"
require "json"

# 將孩童的夢想描述轉成給 Replicate 繪圖用的英文 Prompt。
# 使用 Google Gemini API；金鑰來自 ApiKeys.gemini_api_key（.env 或 credentials）。
class GeminiService
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
  # GCP Generative Language API 可用：gemini-2.0-flash、gemini-1.5-pro；若 404 請至 API 文件查最新名稱
  MODEL = "gemini-2.0-flash"

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

  # 25 歲擬真職業照用 Prompt（給 InstantID 等擬真模型）
  # @param career [String] 希望職業，例如「醫生」「太空人」
  # @return [String] 英文擬真繪圖用 Prompt（固定 25 歲、photorealistic）
  def self.prompt_for_photorealistic_career(career:)
    new(dream: career.to_s.strip, gender: nil, age: "25").prompt_for_photorealistic_career
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

  def prompt_for_photorealistic_career
    key = ApiKeys.gemini_api_key
    raise MissingApiKey, "GEMINI_API_KEY 未設定（請檢查 .env 或 credentials）" if key.blank?

    body = {
      contents: [{ parts: [{ text: photorealistic_career_prompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 512, responseMimeType: "text/plain" }
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

    text = JSON.parse(res.body).dig("candidates", 0, "content", "parts", 0, "text")
    raise ApiError, "Gemini 未回傳文字" if text.blank?

    text.strip
  end

  private

  def photorealistic_career_prompt
    <<~PROMPT.strip
      你是一位為「擬真職業照」撰寫 image generation prompt 的專家。請根據以下職業，產出「一段」英文的 prompt，給擬真人像模型（InstantID）使用。

      重要：這是「同一人長大後」的職業照。參考圖可能是孩童或青少年，你必須強烈強調「約 30 歲成人模樣」。
      要求：
      - 只輸出「一段」英文描述，不要編號、不要分點、不要標題。
      - 開頭務必寫：aged to 30 years old, mature adult, same person grown up, adult face with defined jawline, mature skin texture, no baby fat。接著描述：亞洲人、穿著該職業服裝、在該職業典型情境中。
      - 務必寫入：30 years old, adult proportions, professional portrait。風格：photorealistic, professional photo, high quality portrait。絕對不要出現 child、kid、teen、young、baby。
      - 長度約 1～3 句，用逗號分隔。不要輸出任何中文或說明，只輸出這一段英文。

      希望職業：#{@dream}
    PROMPT
  end

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
