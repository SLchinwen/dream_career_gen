# frozen_string_literal: true

# 網頁版：上傳／貼圖＋選擇職業 → 呼叫 API 生成職業照
class PagesController < ApplicationController
  def career_photo
    # 僅渲染表單頁，實際呼叫 API 由前端 JavaScript 發送 POST /api/career_photo
  end

  def career_photo_fast
    # 方案 B：純 Gemini 流程，速度較快
  end

  # People of Action 投稿自評：表單頁（GET）與送出評分（POST）
  # 支援「相片網址」或「上傳相片」二擇一；FB 等無法直連時請用上傳
  # 若請求 Accept: application/json 則回傳 JSON（供前端 AJAX 分段顯示用）
  def rotary_photo_score
    return unless request.post?

    photo = params[:photo]
    image_url = params[:image_url].to_s.strip
    description = params[:description].to_s.strip

    if description.blank?
      @error = "請填寫服務說明（約 100 字）"
      return render_json_error if request.format.json?
      return
    end

    if photo.present?
      # 優先使用上傳檔案（FB 等網址無法讀取時可用）
      @image_url = nil
      @result = Rotary::PhotoScoreService.call(photo: photo, description: description)
    elsif image_url.present?
      unless image_url.match?(%r{\Ahttps?://})
        @error = "相片網址必須以 http:// 或 https:// 開頭"
        return render_json_error if request.format.json?
        return
      end
      @image_url = image_url
      @result = Rotary::PhotoScoreService.call(image_url: image_url, description: description)
    else
      @error = "請填寫相片網址或上傳相片（二擇一）"
      return render_json_error if request.format.json?
      return
    end

    if request.format.json?
      render json: @result
      return
    end
  rescue Rotary::PhotoScoreService::MissingApiKey => e
    @error = "系統未設定 GEMINI_API_KEY：#{e.message}"
    @image_url = image_url
    return render_json_error(503) if request.format.json?
  rescue Rotary::PhotoScoreService::ApiError => e
    @error = "評分失敗：#{e.message}"
    @image_url = image_url
    return render_json_error if request.format.json?
  rescue ArgumentError => e
    @error = e.message
    @image_url = image_url
    return render_json_error if request.format.json?
  rescue StandardError => e
    Rails.logger.error("rotary_photo_score error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    @error = "發生錯誤，請稍後再試：#{e.message}"
    @image_url = image_url
    @description = description
    return render_json_error(500) if request.format.json?
  end

  # 僅檢查圖片網址是否可讀取（供前端步驟 1 顯示）
  def rotary_photo_score_check
    image_url = params[:image_url].to_s.strip
    if image_url.blank?
      return render json: { error: "請填寫相片網址" }, status: :unprocessable_entity
    end
    unless image_url.match?(%r{\Ahttps?://})
      return render json: { error: "相片網址必須以 http:// 或 https:// 開頭" }, status: :unprocessable_entity
    end

    Rotary::PhotoScoreService.check_image_url(image_url)
    render json: { status: "ok", message: "圖片可讀取" }
  rescue Rotary::PhotoScoreService::ApiError, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def render_json_error(status = 422)
    render json: { error: @error }, status: status
  end
end
