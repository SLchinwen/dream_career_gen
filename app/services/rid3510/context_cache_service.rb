# frozen_string_literal: true

require "net/http"
require "json"

# 建立並持有「合併意圖」的 Gemini Context Cache，供 ReplyService 重複使用以降低成本與延遲。
# 使用 Google AI API（generativelanguage.googleapis.com）cachedContents。
module Rid3510
  class ContextCacheService
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    MODEL = "gemini-2.0-flash"
    CACHE_TTL_SECONDS = 3600
    # 與 ReplyService 一致：親切助理、簡單白話、結論先行、不帶出處與引用
    SYSTEM_PROMPT = "你是國際扶輪 3510 地區的親切助理。請用簡單白話回答：先給結論，再簡短補充說明。不要列出出處、檔案名或引用。根據以下知識庫內容回答；若無相關資料，請簡短說明並建議聯繫地區 e 化主委或地區辦事處。回答請用繁體中文。"

    class Error < StandardError; end
    class MissingApiKey < Error; end
    class ApiError < Error; end

    # 程序內快取：cache 名稱與過期時間（避免每請求都呼叫 create）
    @cache_name = nil
    @cache_expires_at = nil
    @mutex = Mutex.new

    class << self
      # @return [String, nil] cachedContents 名稱（如 "cachedContents/xxx"），失敗或未設定 key 則 nil
      def get_or_create
        return nil if ApiKeys.gemini_api_key.blank?

        @mutex.synchronize do
          return @cache_name if @cache_name.present? && @cache_expires_at && Time.current < @cache_expires_at
          name = create_cached_content
          if name.present?
            @cache_name = name
            @cache_expires_at = Time.current + CACHE_TTL_SECONDS - 60
          else
            @cache_name = nil
          end
          @cache_name
        end
      end

      def clear_cached_name
        @mutex.synchronize do
          @cache_name = nil
          @cache_expires_at = nil
        end
      end

      private

      def create_cached_content
        key = ApiKeys.gemini_api_key
        raise MissingApiKey, "GEMINI_API_KEY 未設定" if key.blank?

        date_line = new_date_context_line
        merged = KnowledgeService.new.merged_context_for_cache(max_chars: 12_000)
        prefix_text = "#{date_line}\n\n【知識庫內容】\n#{merged[0, 32_000]}"

        body = {
          model: "models/#{MODEL}",
          systemInstruction: { parts: [ { text: SYSTEM_PROMPT } ] },
          contents: [ { role: "user", parts: [ { text: prefix_text } ] } ],
          ttl: "#{CACHE_TTL_SECONDS}s"
        }

        uri = URI("#{BASE_URL}/cachedContents")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 15
        http.read_timeout = 60

        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req["x-goog-api-key"] = key
        req.body = body.to_json

        res = http.request(req)
        unless res.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("[Rid3510::ContextCacheService] create failed: #{res.code} #{res.body[0, 300]}")
          return nil
        end

        data = JSON.parse(res.body)
        data["name"]
      rescue StandardError => e
        Rails.logger.warn("[Rid3510::ContextCacheService] #{e.message}")
        nil
      end

      def new_date_context_line
        today = Date.current
        year_str = today.month >= 7 ? "#{today.year}-#{(today.year + 1) % 100}" : "#{today.year - 1}-#{today.year % 100}"
        "【系統日期】今日為 #{today.year}年#{today.month}月#{today.day}日。當前扶輪年度為 #{year_str}。使用者問「目前總監」「這屆總監」「今年」時請依此年度回答。"
      end
    end
  end
end
