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
    SYSTEM_PROMPT = "你是國際扶輪 3510 地區的知識庫助理。請根據以下「知識庫內容」簡潔回答使用者的問題。若資料中無答案，請說明並建議聯繫地區 e 化主委或地區辦事處。回答請用繁體中文。"

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
        if cache_name.present?
          ask_gemini_with_cache(message, history, cache_name)
        else
          context = KnowledgeService.new.context_for_intent(intent, max_chars: 6000)
          ask_gemini(message, context)
        end
      rescue MissingApiKey, ApiError => e
        "查詢時發生錯誤，請稍後再試或聯繫地區 e 化主委。（#{e.message[0, 100]}）"
      end

      ConversationStore.new.append_if_meaningful(conversation_id, message, reply)

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

    # 使用 Context Cache：contents = 歷史多輪 + 本次使用者訊息
    def ask_gemini_with_cache(user_message, history_turns, cache_name)
      key = ApiKeys.gemini_api_key
      raise MissingApiKey, "GEMINI_API_KEY 未設定（請檢查 .env 或 credentials）" if key.blank?

      contents = ConversationStore.to_contents(history_turns)
      contents << { role: "user", parts: [{ text: user_message }] }

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
        contents: [{ parts: [{ text: full_prompt }] }],
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
