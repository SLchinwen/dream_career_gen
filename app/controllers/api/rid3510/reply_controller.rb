# frozen_string_literal: true

module Api
  module Rid3510
    # POST /stage1/reply 或 POST /api/rid3510/reply
    # Body: { "message": "使用者輸入" }
    # 回傳: { "reply": "回覆文字", "intent": "意圖" }
    class ReplyController < ActionController::Base
      skip_before_action :verify_authenticity_token
      before_action :set_default_format_json

      def create
        message = params[:message].to_s.strip
        if message.blank?
          return render json: { reply: "請提供 message 內容。", intent: "fallback" }, status: :unprocessable_entity
        end

        conversation_id = params[:conversation_id].to_s.presence
        result = ::Rid3510::ReplyService.call(message, conversation_id: conversation_id)
        render json: { reply: result[:reply], intent: result[:intent], conversation_id: result[:conversation_id] }
      rescue StandardError => e
        Rails.logger.error("[Rid3510::Reply] #{e.message}")
        render json: { reply: "系統忙碌中，請稍後再試。", intent: "fallback" }, status: :internal_server_error
      end

      private

      def set_default_format_json
        request.format = :json unless params[:format]
      end
    end
  end
end
