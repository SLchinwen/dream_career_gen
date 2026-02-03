# frozen_string_literal: true

module Api
  module Rotary
    # People of Action 自評 API（供排程逐筆呼叫）
    # POST /api/rotary/photo_scores
    # Header: Authorization: Bearer <ROTARY_API_KEY> 或 X-API-Key: <ROTARY_API_KEY>
    # Body: description (必填), submission_id (選填), 且 photo（檔案）或 image_url（字串）擇一必填
    # 回傳 JSON: { score, score_max, summary, consistency [, submission_id ] }
    class PhotoScoresController < BaseController
      def create
        photo = params[:photo]
        image_url = params[:image_url].to_s.strip.presence
        description = params[:description].to_s.strip
        submission_id = params[:submission_id].to_s.strip.presence

        if description.blank?
          return render json: { error: "description 為必填" }, status: :unprocessable_entity
        end
        if image_url.present?
          unless image_url.match?(%r{\Ahttps?://})
            return render json: { error: "image_url 必須以 http:// 或 https:// 開頭" }, status: :unprocessable_entity
          end
          result = Rotary::PhotoScoreService.call(image_url: image_url, description: description)
        elsif photo.present?
          result = Rotary::PhotoScoreService.call(photo: photo, description: description)
        else
          return render json: { error: "請提供 photo（上傳檔案）或 image_url（圖片網址）" }, status: :unprocessable_entity
        end

        result[:submission_id] = submission_id if submission_id
        render json: result
      rescue Rotary::PhotoScoreService::MissingApiKey => e
        render json: { error: "API 金鑰未設定：#{e.message}" }, status: :service_unavailable
      rescue Rotary::PhotoScoreService::ApiError, ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
