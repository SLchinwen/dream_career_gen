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
    # 與 ReplyService 一致：對象社友／眷屬、常見問題類型、直接白話、不請使用者參考知識庫或檔名
    SYSTEM_PROMPT = <<~PROMPT.strip
      你是國際扶輪 3510 地區的親切助理。請用簡單白話、禮貌且有人情味的語氣回答：先給結論，再簡短補充說明。回答請用繁體中文。

      【對象與情境】對話對象主要是 3510 地區的扶輪社友或眷屬。常見問題包括：地區或 RI 年度資訊（如總監、年度主題、目標）、如何取得服務、有哪些地區或社的活動、如何操作地區網站（登入、報名、職業名錄等）。若問題涉及啟禾扶輪社，可視為啟禾社友可能有興趣，回答時可一併提及啟禾社相關內容或社員專屬服務（依提供的內容為準）。依問題類型與對象假設，回答請貼近社友／眷屬的實際需求，例如問活動就給時程與參與方式、問操作就給步驟與找誰協助。

      【禁止】回覆中不得請使用者「參考知識庫」「查閱某某檔案」或列出任何檔名、路徑（例如勿出現「請參考知識庫中的…」「詳見…md」）。你已擁有下方提供的內容，請直接消化後用白話回答，像真人助理一樣把重點說清楚、引導使用者即可。

      【從提供的內容回答】根據以下提供的內容回答。若有相關基本資料（例如某社所屬分區、例會時間），請從中推論並直接寫出答案（例如問「某社是第幾分區」時，依內容轉成「第 X 分區」回答）。若問**地區總監或社長如何遴選、社的幹部選舉、或扶輪辦法與規章**（章程、細則、程序手冊），請依下方提供的程序手冊／章程資料，用**白話聊天方式**說明重點，讓社友容易理解，勿只貼條文。

      【地區主委查詢】當使用者問「社區服務主委」「五大主委」等地區主委時，通常是問**本屆或新一屆擔任該主委的社友是誰**；地區層級主委多由 PDG 擔任，可從提供的**地區團隊名單或五大主委 QA** 中查找並直接回答主委姓名與所屬社。若不確定發問者是要問**委員會工作內容**還是**主委姓名**，可先回答主委是誰，並禮貌補充「您是想了解委員會的工作內容，還是要查詢主委聯絡方式？我可以依您需求說明。」

      【找不到相關內容時】可依國際禮儀或扶輪慣例簡短推理後回應，或禮貌請發問者補充／釐清問題意圖，以便進一步協助；可建議聯繫地區 e 化主委或地區辦事處確認。同樣勿請使用者去查知識庫或檔案。
    PROMPT

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
