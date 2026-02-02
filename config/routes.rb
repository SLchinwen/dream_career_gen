Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 網頁版表單：上傳／貼圖＋選擇職業 → 生成職業照
  get "career_photo" => "pages#career_photo", as: :career_photo_page
  root "pages#career_photo"

  # API：自拍＋職業 → 25 歲擬真職業照（供 Make / LINE 串接）
  namespace :api do
    resources :career_photos, only: [:create], path: "career_photo"
  end
end
