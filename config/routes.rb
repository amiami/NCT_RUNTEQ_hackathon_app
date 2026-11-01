Rails.application.routes.draw do
  root "staff/operations#index"

  # ヘッダーのスイッチ：操作する人（部長／スタッフ）を切り替える
  resource :operator, only: :update

  namespace :admin do
    resources :operations, only: :index
    resource :skill_map, only: :show
    resources :trainings, only: :index
    resources :manual_revisions, only: :index
  end

  namespace :staff do
    resources :operations, only: :index
    resources :skills, only: :index
    resources :manual_revisions, only: :index
  end

  # ヘルスチェック（デプロイ先の死活監視で使う）
  get "up" => "rails/health#show", as: :rails_health_check
end
