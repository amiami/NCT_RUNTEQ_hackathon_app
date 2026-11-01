Rails.application.routes.draw do
  # トップページ：立場に合った最初の画面に移る（部長 → 管理者の作業ツリー、スタッフ → 作業マニュアル）
  root "homes#show"

  # ヘッダーのスイッチ：操作する人（部長／スタッフ）を切り替える
  resource :operator, only: :update

  namespace :admin do
    resources :operations, only: :index
    resource :skill_map, only: :show
    resources :trainings, only: :index
    resources :manual_revisions, only: :index
  end

  # 管理者の見立て。スキルマップの「変更を保存」で、複数のマスをまとめて保存する（管理者だけ）
  namespace :skills do
    resource :assessment, only: :update
  end

  namespace :staff do
    resources :operations, only: :index
    resources :skills, only: :index
    resources :manual_revisions, only: :index
  end

  # ヘルスチェック（デプロイ先の死活監視で使う）
  get "up" => "rails/health#show", as: :rails_health_check
end
