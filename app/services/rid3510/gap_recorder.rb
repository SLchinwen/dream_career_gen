# frozen_string_literal: true

# 當聊天機器人可能「無法回答」或使用 fallback 時，寫入一筆紀錄到 JSONL，
# 供定期任務（rid3510:process_gaps）讀取、去重、產出建議 QA 或待補知識庫清單。
module Rid3510
  class GapRecorder
    REPLY_PREVIEW_LENGTH = 400
    FALLBACK_PHRASE = "聯繫地區 e 化主委"
    FALLBACK_PHRASE_ALT = "地區辦事處"

    class << self
      # 是否應紀錄此回合（意圖 fallback、知識庫空、或回覆含 fallback 用語）
      def should_record?(intent:, context_was_empty:, reply:)
        return true if intent.to_s == IntentDetector::INTENT_FALLBACK
        return true if context_was_empty
        return true if reply.to_s.include?(FALLBACK_PHRASE) || reply.to_s.include?(FALLBACK_PHRASE_ALT)
        false
      end

      # 寫入一筆 gap 紀錄（非阻塞、錯誤不影響主流程）
      # @param user_message [String]
      # @param intent [String]
      # @param context_was_empty [Boolean]
      # @param reply [String] 完整回覆，內部只存前 REPLY_PREVIEW_LENGTH 字
      # @param conversation_id [String, nil]
      def record(user_message:, intent:, context_was_empty:, reply:, conversation_id: nil)
        return unless should_record?(intent: intent, context_was_empty: context_was_empty, reply: reply)

        payload = {
          at: Time.current.iso8601,
          user_message: user_message.to_s.strip[0, 2000],
          intent: intent.to_s,
          context_was_empty: context_was_empty,
          reply_preview: reply.to_s.strip[0, REPLY_PREVIEW_LENGTH],
          conversation_id: conversation_id.to_s.presence
        }
        append_line(payload)
      rescue StandardError => e
        Rails.logger.warn("[Rid3510::GapRecorder] record failed: #{e.message}")
      end

      private

      def gaps_path
        Rails.root.join("storage", "rid3510", "chat_gaps.jsonl")
      end

      def append_line(payload)
        path = gaps_path
        path.parent.mkpath unless path.parent.exist?
        File.open(path, "a") { |f| f.puts(payload.to_json) }
      end
    end
  end
end
