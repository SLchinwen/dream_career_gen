# frozen_string_literal: true

require "net/http"
require "json"
require "base64"

# 方案 B：純 Gemini 流程（Vision 讀臉部特徵 → Imagen 產圖）
# 不依賴 Replicate，速度較快（約 10–30 秒），相似度較低
class GeminiCareerFastService
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
  MODEL_VISION = "gemini-2.0-flash"
  MODEL_IMAGE = "gemini-2.5-flash-image"

  class Error < StandardError; end
  class MissingApiKey < Error; end
  class ApiError < Error; end

  # @param image_url [String] 人臉圖的 HTTPS URL 或 data URL (data:image/xxx;base64,...)
  # @param career [String] 希望職業
  # @param gender [String, nil] 性別（"男"、"女" 或空為不指定）
  # @return [Hash] { image_data_url: "data:image/png;base64,...", prompt_used: "..." }
  def self.generate(image_url:, career:, gender: nil)
    new(image_url: image_url, career: career, gender: gender).generate
  end

  def initialize(image_url:, career:, gender: nil)
    @image_url = image_url.to_s.strip
    @career = career.to_s.strip
    @gender = gender.to_s.strip.presence
  end

  def generate
    key = ApiKeys.gemini_api_key
    raise MissingApiKey, "GEMINI_API_KEY 未設定" if key.blank?
    raise ApiError, "image_url 不可為空" if @image_url.blank?
    raise ApiError, "career 不可為空" if @career.blank?

    image_data = parse_image_to_base64(@image_url)
    face_desc = describe_face_as_adult(image_data, key)
    career_desc = career_to_image_description(key)
    prompt = build_image_prompt(face_desc, career_desc)
    image_base64 = generate_image(prompt, key)

    mime = "image/png"
    data_url = "data:#{mime};base64,#{image_base64}"
    { image_data_url: data_url, prompt_used: prompt }
  end

  private

  def parse_image_to_base64(url_or_data)
    if url_or_data.start_with?("data:")
      # data:image/jpeg;base64,xxxx
      parts = url_or_data.split(",", 2)
      @image_mime = parts[0].match(%r{data:([^;]+)})&.[](1) || "image/jpeg"
      return parts[1] if parts.size == 2
      raise ApiError, "無效的 data URL"
    end

    @image_mime = "image/jpeg"
    # HTTPS URL：下載並轉 base64
    uri = URI(url_or_data)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30
    res = http.request(Net::HTTP::Get.new(uri))
    raise ApiError, "無法取得圖片: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    Base64.strict_encode64(res.body)
  end

  def describe_face_as_adult(image_base64, key)
    gender_instruction = @gender.present? ? "\n**重要**：此人為「#{@gender}」，請在描述開頭明確寫出 male 或 female，切勿搞錯性別。" : ""
    prompt = <<~PROMPT.strip
      你是一位專業的人像分析師。請仔細觀察這張人臉照片，描述以下特徵的「30 歲成人版本」：
      #{gender_instruction}

      1. 性別（若使用者已指定則依其指定，否則依照片判斷）：male 或 female，務必正確
      2. 膚色、族裔（若可判斷，例如亞洲人）
      3. 臉型（圓臉、橢圓、方臉等）長大後的輪廓
      4. 髮型、髮色、髮量
      5. 五官特徵（眼睛、鼻子、眉毛）在成人後的大致樣貌
      6. **務必保留**：若有痣，請描述其位置（如 left cheek, chin）並寫入描述；若有特殊傷疤，請描述位置並保留；若為單眼皮（single eyelids），務必寫入 "single eyelids" 或 "monolid" 保留此特徵。

      請用「一段」英文描述，開頭寫 "A 30-year-old #{@gender == "男" ? "male" : @gender == "女" ? "female" : "adult"} with "，接著描述上述特徵，並明確標註痣／傷疤的位置與單雙眼皮。
      只輸出這一段英文，不要編號、不要分點、不要中文。長度約 2～5 句。
    PROMPT

    body = {
      contents: [
        {
          parts: [
            {
              inline_data: {
                mime_type: @image_mime || "image/jpeg",
                data: image_base64
              }
            },
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.6,
        maxOutputTokens: 512,
        responseMimeType: "text/plain"
      }
    }

    uri = URI("#{BASE_URL}/models/#{MODEL_VISION}:generateContent")
    res = call_gemini(uri, key, body)
    text = res.dig("candidates", 0, "content", "parts", 0, "text")
    raise ApiError, "Gemini Vision 未回傳描述" if text.blank?

    text.strip
  end

  def career_to_image_description(key)
    prompt = <<~PROMPT.strip
      職業：「#{@career}」
      請用「一句」英文描述：此人作為該職業時應穿的服裝、所在的工作地點、手持或周圍的道具。
      範例：歌手 → "wearing stage performance outfit, holding a microphone, standing on a concert stage or in a recording studio"
      範例：廚師 → "wearing white chef's coat and hat, standing in a professional kitchen with stainless steel equipment"
      範例：太空人 → "wearing astronaut suit, standing in space station or with Earth in background"
      只輸出這一句英文描述，不要編號、不要其他說明。
    PROMPT

    body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 256,
        responseMimeType: "text/plain"
      }
    }

    uri = URI("#{BASE_URL}/models/#{MODEL_VISION}:generateContent")
    res = call_gemini(uri, key, body)
    text = res.dig("candidates", 0, "content", "parts", 0, "text")
    return "wearing professional attire in work setting" if text.blank?

    text.strip
  end

  def build_image_prompt(face_desc, career_desc)
    gender_note = @gender == "男" ? " The person must be male. " : @gender == "女" ? " The person must be female. " : " "
    <<~PROMPT.strip
      CRITICAL: The person must be depicted EXACTLY as a #{@career}. The outfit, setting, and props must match ONLY this profession.#{gender_note}

      A photorealistic full-body portrait: #{face_desc}. #{career_desc}. Full body shot from head to feet, clearly showing the #{@career}-specific attire and workplace. Professional photo, soft lighting, high quality, 30 years old adult, confident pose. No child, no baby, no cartoon style. The scene must unmistakably show a #{@career}.
    PROMPT
  end

  def generate_image(prompt, key)
    body = {
      contents: [
        {
          parts: [{ text: prompt }]
        }
      ],
      generationConfig: {
        responseModalities: ["TEXT", "IMAGE"],
        imageConfig: { aspectRatio: "3:4" }
      }
    }

    uri = URI("#{BASE_URL}/models/#{MODEL_IMAGE}:generateContent")
    res = call_gemini(uri, key, body, read_timeout: 60)
    parts = res.dig("candidates", 0, "content", "parts") || []

    parts.each do |part|
      next unless part["inlineData"]

      data = part.dig("inlineData", "data")
      return data if data.present?
    end

    raise ApiError, "Gemini Imagen 未回傳圖片"
  end

  def call_gemini(uri, key, body, read_timeout: 30)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = read_timeout

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["x-goog-api-key"] = key
    req.body = body.to_json

    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      raise ApiError, "Gemini API 錯誤: #{res.code} - #{res.body[0, 500]}"
    end

    JSON.parse(res.body)
  end
end
