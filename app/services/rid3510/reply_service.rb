# frozen_string_literal: true

require "net/http"
require "json"
require "securerandom"

# RID3510 階段 1 回覆：意圖辨識 → 知識庫 context → Gemini → { reply, intent, conversation_id }。
# 支援多輪對話（Redis 最近 10 輪、僅寫入有意義回合）、可選 Context Caching（合併意圖）。
module Rid3510
  class ReplyService
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    MODEL = "gemini-2.0-flash"
    # 角色與對象：地區社友／眷屬；常見問題類型；親切白話、不請使用者參考知識庫或檔名
    SYSTEM_PROMPT = <<~PROMPT.strip
      你是國際扶輪 3510 地區的親切助理。請用簡單白話、禮貌且有人情味的語氣回答：先給結論，再簡短補充說明。回答請用繁體中文。

      【對象與情境】對話對象主要是 3510 地區的扶輪社友或眷屬。常見問題包括：地區或 RI 年度資訊（如總監、年度主題、目標）、如何取得服務、有哪些地區或社的活動、如何操作地區網站（登入、報名、職業名錄等）。若問題涉及啟禾扶輪社，可視為啟禾社友可能有興趣，回答時可一併提及啟禾社相關內容或社員專屬服務（依提供的內容為準）。依問題類型與對象假設，回答請貼近社友／眷屬的實際需求，例如問活動就給時程與參與方式、問操作就給步驟與找誰協助。

      【禁止】回覆中不得請使用者「參考知識庫」「查閱某某檔案」或列出任何檔名、路徑（例如勿出現「請參考知識庫中的…」「詳見…md」）。你已擁有下方提供的內容，請直接消化後用白話回答，像真人助理一樣把重點說清楚、引導使用者即可。

      【從提供的內容回答】根據以下提供的內容回答。若有相關基本資料（例如某社所屬分區、例會時間），請從中推論並直接寫出答案（例如問「某社是第幾分區」時，依內容轉成「第 X 分區」回答）。

      【找不到相關內容時】可依國際禮儀或扶輪慣例簡短推理後回應，或禮貌請發問者補充／釐清問題意圖，以便進一步協助；可建議聯繫地區 e 化主委或地區辦事處確認。同樣勿請使用者去查知識庫或檔案。
    PROMPT

    class Error < StandardError; end
    class MissingApiKey < Error; end
    class ApiError < Error; end

    # @param message [String] 使用者輸入
    # @param conversation_id [String, nil] 選填；未傳則產生新 id 並在回傳中帶出
    # @return [Hash] { reply: String, intent: String, conversation_id: String }
    def self.call(message, conversation_id: nil)
      new.call(message, conversation_id: conversation_id)
    end

    def call(message, conversation_id: nil)
      conversation_id = conversation_id.presence || SecureRandom.uuid
      intent = IntentDetector.detect(message)
      history = ConversationStore.new.recent_turns(conversation_id)
      cache_name = ContextCacheService.get_or_create

      reply = begin
        intent_context = KnowledgeService.new.context_for_intent(intent, max_chars: 6000)
        if cache_name.present?
          ask_gemini_with_cache(message, history, cache_name, intent_context: intent_context)
        else
          ask_gemini(message, intent_context)
        end
      rescue MissingApiKey, ApiError => e
        "查詢時發生錯誤，請稍後再試或聯繫地區 e 化主委。（#{e.message[0, 100]}）"
      end

      ConversationStore.new.append_if_meaningful(conversation_id, message, reply)

      context_was_empty = (intent_context == KnowledgeService::DEFAULT_FALLBACK_MESSAGE)
      GapRecorder.record(
        user_message: message,
        intent: intent,
        context_was_empty: context_was_empty,
        reply: reply,
        conversation_id: conversation_id
      )

      { reply: reply, intent: intent, conversation_id: conversation_id }
    end

    private

    def current_rotary_year
      today = Date.current
      if today.month >= 7
        "#{today.year}-#{(today.year + 1) % 100}"
      else
        "#{today.year - 1}-#{today.year % 100}"
      end
    end

    def date_context_line
      today = Date.current
      year_str = current_rotary_year
      "【系統日期】今日為 #{today.year}年#{today.month}月#{today.day}日。當前扶輪年度為 #{year_str}。使用者問「目前總監」「這屆總監」「今年」時請依此年度回答。"
    end

    # 使用 Context Cache：contents = 本次意圖知識庫（避免合併 cache 截斷漏掉） + 歷史多輪 + 本次使用者訊息
    def ask_gemini_with_cache(user_message, history_turns, cache_name, intent_context: nil)
      key = ApiKeys.gemini_api_key
      raise MissingApiKey, "GEMINI_API_KEY 未設定（請檢查 .env 或 credentials）" if key.blank?

      contents = []
      if intent_context.present? && intent_context != KnowledgeService::DEFAULT_FALLBACK_MESSAGE
        contents << { role: "user", parts: [ { text: "【本次問題相關知識庫】\n#{intent_context[0, 6000]}" } ] }
        contents << { role: "model", parts: [ { text: "已讀取上述知識庫，請提出您的問題。" } ] }
      end
      contents.concat(ConversationStore.to_contents(history_turns))
      contents << { role: "user", parts: [ { text: user_message } ] }

      body = {
        cachedContent: cache_name,
        contents: contents,
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1024,
          responseMimeType: "text/plain"
        }
      }

      uri = URI("#{BASE_URL}/models/#{MODEL}:generateContent")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

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

    def ask_gemini(user_message, context)
      key = ApiKeys.gemini_api_key
      raise MissingApiKey, "GEMINI_API_KEY 未設定（請檢查 .env 或 credentials）" if key.blank?

      user_content = "#{date_context_line}\n\n【知識庫內容】\n#{context[0, 8000]}\n\n【使用者問題】\n#{user_message}"
      full_prompt = "#{SYSTEM_PROMPT}\n\n---\n\n#{user_content}"

      body = {
        contents: [ { parts: [ { text: full_prompt } ] } ],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1024,
          responseMimeType: "text/plain"
        }
      }

      uri = URI("#{BASE_URL}/models/#{MODEL}:generateContent")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

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
    rescue MissingApiKey, ApiError => e
      "查詢時發生錯誤，請稍後再試或聯繫地區 e 化主委。（#{e.message[0, 100]}）"
    end
  end
end
