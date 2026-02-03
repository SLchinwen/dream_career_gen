# frozen_string_literal: true

require "net/http"
require "json"
require "base64"

module Rotary
  # People of Action 投稿相片＋說明 → 自評分數與評語。
  # 依 KB 以 Gemini 多模態（圖片＋文字）評分，回傳 0–30 分與摘要。
  class PhotoScoreService
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    MODEL = "gemini-2.0-flash"

    class Error < StandardError; end
    class MissingApiKey < Error; end
    class ApiError < Error; end

    # @param photo [ActionDispatch::Http::UploadedFile, String, nil] 上傳的圖片或檔案路徑（與 image_url 二擇一）
    # @param image_url [String, nil] 圖片網址（與 photo 二擇一）
    # @param description [String] 約 100 字服務說明
    # @return [Hash] { score:, score_max:, summary:, consistency: }
    def self.call(photo: nil, image_url: nil, description:)
      new(photo: photo, image_url: image_url, description: description).call
    end

    # 僅檢查圖片網址是否可讀取（供前端分段顯示用）
    # @return [Hash] { status: "ok", message: "圖片可讀取" }
    def self.check_image_url(url)
      url = url.to_s.strip
      raise ArgumentError, "請提供圖片網址" if url.blank?
      raise ArgumentError, "網址必須以 http:// 或 https:// 開頭" unless url.match?(%r{\Ahttps?://})

      new(photo: nil, image_url: url, description: "").send(:fetch_image_from_url, url)
      { status: "ok", message: "圖片可讀取" }.freeze
    end

    def initialize(photo: nil, image_url: nil, description:)
      @photo = photo
      @image_url = image_url.to_s.strip.presence
      @description = description.to_s.strip
    end

    def call
      key = ApiKeys.gemini_api_key
      raise MissingApiKey, "GEMINI_API_KEY 未設定" if key.blank?

      image_data, mime_type = read_image
      kb_text = File.read(Rails.root.join("app/services/rotary/people_of_action_kb.txt"))

      body = {
        contents: [
          {
            parts: [
              { inline_data: { mime_type: mime_type, data: image_data } },
              { text: build_prompt(kb_text) }
            ]
          }
        ],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 1024,
          responseMimeType: "application/json"
        }
      }

      uri = URI("#{BASE_URL}/models/#{MODEL}:generateContent")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 120

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["x-goog-api-key"] = key
      req.body = body.to_json

      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        msg = parse_gemini_error(res)
        raise ApiError, msg
      end

      text = JSON.parse(res.body).dig("candidates", 0, "content", "parts", 0, "text")
      raise ApiError, "Gemini 未回傳內容" if text.blank?

      parse_response(text.strip)
    end

    private

    def read_image
      raw = nil
      mime = "image/jpeg"

      if @image_url.present?
        raw, mime = fetch_image_from_url(@image_url)
      elsif @photo.respond_to?(:read)
        @photo.rewind
        raw = @photo.read
        mime = @photo.content_type.presence || "image/jpeg"
      elsif @photo.is_a?(String) && File.file?(@photo)
        raw = File.binread(@photo)
      end

      raise ArgumentError, "請提供圖片網址（image_url）或上傳檔案（photo）" if raw.blank?

      [Base64.strict_encode64(raw), mime]
    end

    def fetch_image_from_url(url)
      uri = URI(url)
      raise ArgumentError, "圖片網址必須為 http 或 https" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      raw = nil
      content_type_header = nil
      5.times do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 15
        http.read_timeout = 30

        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "Mozilla/5.0 (compatible; DreamCareerGen/1.0)"
        res = http.request(req)

        if res.is_a?(Net::HTTPRedirection) && res["Location"]
          uri = URI.join(uri, res["Location"])
          next
        end

        unless res.is_a?(Net::HTTPSuccess)
          raise ApiError, "無法讀取圖片網址：#{res.code} #{res.message}"
        end

        raw = res.body
        content_type_header = res["Content-Type"].to_s.split(";").first.to_s.strip
        break
      end

      raise ApiError, "無法讀取圖片：網址可能導向過多或未回傳內容" if raw.blank?

      # 若回傳的是 HTML（常見：相簿頁、登入頁），Gemini 會回 400 "image is not valid"
      if raw.start_with?("<!", "<html", "<HTML") || content_type_header.to_s.downcase.include?("text/html")
        raise ApiError, "此網址回傳的是網頁而非圖片。請使用「圖片的直連網址」（右鍵圖片→複製圖片網址，或從圖床取得直接連結）。"
      end

      unless content_type_header.to_s.downcase.start_with?("image/")
        raise ApiError, "此網址回傳的並非圖片（Content-Type: #{content_type_header.presence || '未知'}）。請貼上圖片的直接連結。"
      end

      # 依檔案開頭判斷實際格式，避免標頭與內容不符導致 Gemini 400
      mime = detect_image_mime(raw) || content_type_header || "image/jpeg"
      [raw, mime]
    end

    def parse_gemini_error(res)
      body = res.body.to_s
      if res.code == "400" && body.include?("image is not valid")
        return "圖片無法被辨識（可能非支援格式或已損壞）。請使用 JPG、PNG、GIF 或 WebP 的「直接圖片網址」，並確認網址在瀏覽器開啟後是一張圖而非網頁。"
      end
      data = JSON.parse(body) rescue {}
      msg = data.dig("error", "message") || body[0, 300]
      "Gemini API 錯誤: #{res.code} - #{msg}"
    end

    # 依 magic bytes 判斷 MIME，Gemini 支援 jpeg / png / webp / gif
    def detect_image_mime(raw)
      return "image/jpeg" if raw.to_s.start_with?("\xFF\xD8\xFF")
      return "image/png"  if raw.to_s.start_with?("\x89PNG\r\n\x1A\n")
      return "image/gif"  if raw.to_s.start_with?("GIF87a", "GIF89a")
      return "image/webp" if raw.to_s.start_with?("RIFF") && raw.to_s[8, 4] == "WEBP"
      nil
    end

    def build_prompt(kb_text)
      <<~PROMPT.strip
        你是一位 People of Action 投稿評審助理。請「僅依」以下知識庫對本張相片與投稿說明進行評分，不得脫離知識庫自行延伸解釋。

        --- 知識庫（評分唯一依據）---
        #{kb_text}
        ---

        投稿人提供的服務說明（約 100 字）：
        #{@description}

        重要前提：投稿僅有一張圖片。評分與建議均「不要求」改善前／改善後對比照；P4 成果或改變可由畫面當下情境或說明文字呈現即可。取景建議勿建議「應拍前後對比」。

        請依知識庫判斷：
        1) 圖片是否符合 People of Action（人、行動、影響）三元素；
        2) 依 KB-05 加分/扣分項計算分數（0–30）；
        3) 圖片與上述說明是否一致（一致 / 部分一致 / 不一致，依 KB-04 以圖片為準）；
        4) 針對「如何改善」給投稿人具體建議（兩項，各一至三句）：
           - composition_tip：取景／構圖建議。僅就「這一張」可如何取景改善（例如：拍到社友正在服務的動作、與服務對象的互動、避免純團體照或儀式照）。勿建議「應拍改善前後對比」或「需要兩張圖」。
           - description_tip：說明文字建議。以知識庫「服務說明文字標準」為範本，建議採用「我們透過扶輪＋完成了［具體行動］＋改善了／帶來了［影響］」的敘述方式，並依本張相片內容給出可替換的具體用詞範例（一至兩句），讓投稿人可直接參考改寫。

        請「僅」回傳以下 JSON，不要其他文字或 markdown：
        {"score":<0-30 整數>,"summary":"簡短評語一至三句","consistency":"一致|部分一致|不一致","composition_tip":"取景與構圖的具體改善建議","description_tip":"說明文字如何撰寫的具體建議，可含範例句型"}
      PROMPT
    end

    def parse_response(text)
      # 若 API 回傳被 markdown 包住，先剝掉
      json_str = text.gsub(/\A\s*```(?:json)?\s*/, "").gsub(/\s*```\s*\z/, "").strip
      data = JSON.parse(json_str)

      {
        score: data["score"].to_i.clamp(0, 30),
        score_max: 30,
        summary: data["summary"].to_s.presence || "（無評語）",
        consistency: data["consistency"].to_s.presence || "—",
        composition_tip: data["composition_tip"].to_s.strip.presence,
        description_tip: data["description_tip"].to_s.strip.presence
      }
    rescue JSON::ParserError => e
      Rails.logger.warn("PhotoScoreService JSON parse failed: #{e.message}, raw: #{text[0, 200]}")
      {
        score: 0,
        score_max: 30,
        summary: "評分解析失敗，請重試。",
        consistency: "—",
        composition_tip: nil,
        description_tip: nil
      }
    end
  end
end
