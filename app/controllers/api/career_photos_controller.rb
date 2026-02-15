# frozen_string_literal: true

module Api
  # 自拍＋職業 → 25 歲擬真職業照。供 Make（或 LINE Webhook）呼叫。
  # POST /api/career_photos 參數：image_url（自拍 HTTPS URL）、career（希望職業）
  # 回傳 JSON：{ "image_url": "https://..." } 或 { "error": "訊息" }
  class CareerPhotosController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :set_default_format_json

    # POST /api/career_photos
    # Params: image_url (required), career (required)
    # Returns: { image_url: "https://..." } or { error: "..." }
    def create
      image_url = params[:image_url].to_s.strip.presence
      career = params[:career].to_s.strip.presence

      if image_url.blank?
        return render json: { error: "image_url 為必填" }, status: :unprocessable_entity
      end
      if career.blank?
        return render json: { error: "career 為必填" }, status: :unprocessable_entity
      end
      if image_url.start_with?("data:")
        return render json: {
          error: "本版（Replicate）目前不支援上傳產生的 data URL，且對學童照常失敗。學童自拍＋夢想職業請改用「快版」以穩定生成長大職業照。"
        }, status: :unprocessable_entity
      end

      # 第一階段：SAM 年齡變化，把臉長大至約 30 歲（失敗則用原圖）
      face_url = image_url
      begin
        face_url = AgeProgressionService.age_to(image_url: image_url)
      rescue AgeProgressionService::ApiError, AgeProgressionService::PredictionFailed => e
        Rails.logger.warn("Age progression failed, using original image: #{e.message}")
      end

      prompt = GeminiService.prompt_for_photorealistic_career(career: career)
      result_url = InstantIdService.generate(image_url: face_url, prompt: prompt)
      # replicate.delivery 為暫時性連結，請盡快使用或自行下載保存
      render json: { image_url: result_url, url_expires: true }
    rescue GeminiService::MissingApiKey, InstantIdService::MissingApiKey, AgeProgressionService::MissingApiKey => e
      render json: { error: "API 金鑰未設定：#{e.message}" }, status: :service_unavailable
    rescue GeminiService::ApiError, InstantIdService::ApiError, InstantIdService::PredictionFailed => e
      err_msg = e.message
      if err_msg.to_s.include?("list index out of range")
        err_msg = "本服務需傳入學童自拍以模擬長大職業照，但 Replicate 此模型目前對學童照支援不穩（list index out of range）。請改用「快版（純 Gemini）」以達成學童→長大職業照。"
      end
      render json: { error: err_msg }, status: :unprocessable_entity
    end

    private

    def set_default_format_json
      request.format = :json unless params[:format]
    end
  end
end
