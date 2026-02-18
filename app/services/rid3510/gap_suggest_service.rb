# frozen_string_literal: true

require "net/http"
require "json"

# 針對「無法回答」的使用者問題，呼叫 Gemini 產生建議意圖與建議答案，供待補 QA 報告使用。
module Rid3510
  class GapSuggestService
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    MODEL = "gemini-2.0-flash"
    INTENTS = "工作目標、現有活動、E化操作、扶輪知識、基金與獎助金、3510歷史、分區社團與社友查社、社區服務與綠色奇蹟、fallback"

    PROMPT_TEMPLATE = <<~PROMPT.strip
      以下是 3510 地區扶輪社友或眷屬向聊天機器人提出的問題，目前知識庫無法完整回答。請你協助產出「待補 QA」建議。

      【使用者問題】
      %<user_message>s

      【請依以下格式回覆，僅輸出兩行】
      第一行：意圖：<上述問題最適合的意圖，只能從以下選一個：%<intents>s>
      第二行：建議答案：<2～4 句簡短白話答案，給社友看的 FAQ 風格，繁體中文；若無法推論則寫「建議由地區 e 化主委或地區辦事處提供」。>
    PROMPT

    class << self
      # @param user_message [String]
      # @return [Hash, nil] { suggested_intent: String, suggested_answer: String } 或 nil（API 失敗／未設定 key）
      def suggest_qa(user_message)
        return nil if user_message.blank?
        key = ApiKeys.gemini_api_key
        return nil if key.blank?

        prompt = format(PROMPT_TEMPLATE, user_message: user_message.to_s.strip[0, 500], intents: INTENTS)
        text = call_gemini(prompt, key)
        return nil if text.blank?

        parse_response(text)
      rescue StandardError => e
        Rails.logger.warn("[Rid3510::GapSuggestService] suggest_qa failed: #{e.message}")
        nil
      end

      private

      def call_gemini(prompt, key)
        body = {
          contents: [ { parts: [ { text: prompt } ] } ],
          generationConfig: {
            temperature: 0.3,
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
        return nil unless res.is_a?(Net::HTTPSuccess)

        data = JSON.parse(res.body)
        data.dig("candidates", 0, "content", "parts", 0, "text")&.strip
      end

      def parse_response(text)
        intent = nil
        answer = nil
        in_answer = false
        answer_lines = []
        text.each_line do |line|
          line_stripped = line.strip
          if line_stripped.start_with?("意圖：")
            intent = line_stripped.sub(/\A意圖：/, "").strip
            in_answer = false
          elsif line_stripped.start_with?("建議答案：")
            in_answer = true
            answer_lines << line_stripped.sub(/\A建議答案：/, "").strip
          elsif in_answer && line_stripped.present?
            answer_lines << line_stripped
          end
        end
        answer = answer_lines.join("\n").strip if answer_lines.any?
        return nil if intent.blank? && answer.blank?

        { suggested_intent: intent.presence || "fallback", suggested_answer: answer.to_s }
      end
    end
  end
end
