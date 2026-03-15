Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 服務與 API 導覽（首頁）；同機多服務時由此進入各網頁與 API
  root "pages#index"
  get "nav" => "pages#index", as: :service_nav_page

  # 夢想職人照
  get "career_photo_fast" => "pages#career_photo_fast", as: :career_photo_fast_page
  get "career_photo" => "pages#career_photo", as: :career_photo_page

  # RID3510 聊天機器人模擬（測試 stage1/reply）
  get "rid3510/chat" => "pages#rid3510_chat", as: :rid3510_chat_page

  # 共用雲端相簿（GAS 讀取共用硬碟目錄 → 相簿列表與可分享 URL）
  get "albums" => "pages#albums", as: :albums_page
  get "albums/" => redirect("/albums")
  get "albums/:folder_id" => "pages#album_show", as: :album_show_page, constraints: { folder_id: %r{[^/]+} }

  # People of Action 投稿自評（Web：上傳相片＋說明 → 分數與評語）
  get "rotary/photo_score" => "pages#rotary_photo_score", as: :rotary_photo_score
  post "rotary/photo_score" => "pages#rotary_photo_score"
  post "rotary/photo_score_check" => "pages#rotary_photo_score_check", as: :rotary_photo_score_check

  # API：自拍＋職業 → 職業照
  namespace :api do
    resources :career_photos, only: [ :create ], path: "career_photo"
    post "career_photo_fast" => "career_photos_fast#create"

    # People of Action 評分 API（排程用，需 ROTARY_API_KEY）
    namespace :rotary do
      resources :photo_scores, only: [ :create ]
    end

    # RID3510 階段 1 回覆 API（意圖＋知識庫＋Gemini，從子模組 rid3510 讀取）
    namespace :rid3510 do
      post "reply" => "reply#create"
    end
  end

  # 與 Make / LINE 串接同一路徑（對應 rid3510 bot stage1/reply）
  post "stage1/reply" => "api/rid3510/reply#create"
end
