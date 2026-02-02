# frozen_string_literal: true

module Api
  # 方案 B：純 Gemini 流程（Vision + Imagen），速度較快、相似度較低
  # POST /api/career_photo_fast
  class CareerPhotosFastController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :set_default_format_json

    def create
      image_url = params[:image_url].to_s.strip.presence
      career = params[:career].to_s.strip.presence
      gender = params[:gender].to_s.strip.presence

      if image_url.blank?
        return render json: { error: "image_url 為必填" }, status: :unprocessable_entity
      end
      if career.blank?
        return render json: { error: "career 為必填" }, status: :unprocessable_entity
      end

      result = GeminiCareerFastService.generate(image_url: image_url, career: career, gender: gender)
      render json: {
        image_data_url: result[:image_data_url],
        prompt_used: result[:prompt_used],
        mode: "gemini_fast"
      }
    rescue GeminiCareerFastService::MissingApiKey => e
      render json: { error: "API 金鑰未設定：#{e.message}" }, status: :service_unavailable
    rescue GeminiCareerFastService::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def set_default_format_json
      request.format = :json unless params[:format]
    end
  end
end
