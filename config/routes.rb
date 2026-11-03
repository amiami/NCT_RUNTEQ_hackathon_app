Rails.application.routes.draw do
  # トップページ：立場に合った最初の画面に移る（部長 → 管理者の作業ツリー、スタッフ → 作業マニュアル）
  root "homes#show"

  # ヘッダーのスイッチ：操作する人（部長／スタッフ）を切り替える
  resource :operator, only: :update

  namespace :admin do
    resources :operations, only: :index do
      resource :manual, only: [ :edit, :update ], module: :operations
    end
    resource :skill_map, only: :show
    # スキルマップのマスの詳細。マスを押すと、表の上の Turbo Frame に入る
    resources :skills, only: :show
    resources :trainings, only: :index
    # 研修画面の「変更を保存」：下書きの予定の追加・取り消し・期限の変更をまとめて反映する
    resource :training_plan, only: :update
    resources :manual_revisions, only: :index
  end

  # 管理者の見立て。スキルマップの「変更を保存」で、複数のマスをまとめて保存する（管理者だけ）
  namespace :skills do
    resource :assessment, only: :update
  end

  # 研修予定の「教え終わった」。押せるのはその予定の教える人だけなので、管理者・スタッフで共通に使う
  resources :trainings, only: [] do
    resource :completion, only: :create, module: :trainings
  end

  namespace :staff do
    resources :operations, only: :index do
      resource :confirmation, only: :create, module: :operations
      # 自己申告（レベル3・4）。送るのはレベルだけで、操作しているスタッフ本人のスキルを変える
      resource :self_declaration, only: :create, module: :operations
    end
    resources :skills, only: :index
    resources :manual_revisions, only: :index
  end

  # ヘルスチェック（デプロイ先の死活監視で使う）
  get "up" => "rails/health#show", as: :rails_health_check
end
