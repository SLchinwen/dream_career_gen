# frozen_string_literal: true

# 網頁版：上傳／貼圖＋選擇職業 → 呼叫 API 生成職業照
class PagesController < ApplicationController
  def career_photo
    # 僅渲染表單頁，實際呼叫 API 由前端 JavaScript 發送 POST /api/career_photo
  end
end
