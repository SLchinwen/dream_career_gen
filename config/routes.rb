Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 夢想職人照（產品主頁）
  root "pages#career_photo_fast"
  get "career_photo_fast" => "pages#career_photo_fast", as: :career_photo_fast_page
  get "career_photo" => "pages#career_photo", as: :career_photo_page

  # People of Action 投稿自評（Web：上傳相片＋說明 → 分數與評語）
  get "rotary/photo_score" => "pages#rotary_photo_score", as: :rotary_photo_score
  post "rotary/photo_score" => "pages#rotary_photo_score"
  post "rotary/photo_score_check" => "pages#rotary_photo_score_check", as: :rotary_photo_score_check

  # API：自拍＋職業 → 職業照
  namespace :api do
    resources :career_photos, only: [:create], path: "career_photo"
    post "career_photo_fast" => "career_photos_fast#create"

    # People of Action 評分 API（排程用，需 ROTARY_API_KEY）
    namespace :rotary do
      resources :photo_scores, only: [:create]
    end
  end
end
