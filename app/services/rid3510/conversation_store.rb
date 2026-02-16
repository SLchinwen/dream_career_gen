# frozen_string_literal: true

require "json"

# 以 Redis 儲存 RID3510 聊天最近 N 輪對話；未設定 Redis 時不持久化。
# 僅「有意義」的回合才寫入（忽略錯誤提示、空白回覆等）。
module Rid3510
  class ConversationStore
    KEY_PREFIX = "rid3510:chat:"
    MAX_ROUNDS = 10

    # 下列回覆視為無意義，不寫入一輪、不佔 10 輪名額
    MEANINGLESS_REPLY_PREFIXES = [
      "請提供 message 內容",
      "系統忙碌中，請稍後再試",
      "查詢時發生錯誤"
    ].freeze

    def initialize(redis: nil)
      @redis = redis || Rails.application.config.rid3510_redis
    end

    # @param conversation_id [String]
    # @return [Array<Hash>] 每筆 { "role" => "user"|"model", "text" => "..." }，最多 10 輪（20 則）
    def recent_turns(conversation_id)
      return [] if conversation_id.blank? || !available?

      raw = @redis.get(key(conversation_id))
      return [] if raw.blank?

      list = JSON.parse(raw)
      list.is_a?(Array) ? list : []
    rescue StandardError
      []
    end

    # 僅當回覆為「有意義」時才追加一輪；超過 MAX_ROUNDS 輪則刪除最舊的。
    # @param conversation_id [String]
    # @param user_message [String]
    # @param model_reply [String]
    # @return [Boolean] 是否已寫入
    def append_if_meaningful(conversation_id, user_message, model_reply)
      return false if conversation_id.blank? || !available?
      return false unless meaningful_turn?(user_message, model_reply)

      turns = recent_turns(conversation_id)
      turns << { "role" => "user", "text" => user_message.to_s }
      turns << { "role" => "model", "text" => model_reply.to_s }
      # 保留最近 MAX_ROUNDS 輪（每輪 2 則）
      turns = turns.last(MAX_ROUNDS * 2)
      @redis.set(key(conversation_id), turns.to_json)
      true
    rescue StandardError => e
      Rails.logger.warn("[Rid3510::ConversationStore] append failed: #{e.message}")
      false
    end

    # 轉成 Gemini contents 格式： [ { role: "user", parts: [{ text: "..." }] }, { role: "model", parts: [...] } ]
    # @param turns [Array<Hash>] recent_turns 回傳的格式
    # @return [Array<Hash>]
    def self.to_contents(turns)
      Array(turns).map do |t|
        role = t["role"] == "model" ? "model" : "user"
        { role: role, parts: [{ text: t["text"].to_s }] }
      end
    end

    def available?
      @redis.present?
    end

    private

    def key(conversation_id)
      "#{KEY_PREFIX}#{conversation_id}"
    end

    def meaningful_turn?(user_message, model_reply)
      return false if user_message.blank? || model_reply.blank?
      return false if model_reply.length < 2

      MEANINGLESS_REPLY_PREFIXES.none? { |prefix| model_reply.strip.start_with?(prefix) }
    end
  end
end
