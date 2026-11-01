require "rails_helper"

RSpec.describe "トップページ" do
  let(:nakamura) { create(:user, name: "中村 健太", sort_order: 1) }

  # 何も選んでいないときに部長として扱われるよう、管理者を用意しておく
  before { create(:user, :admin, name: "管理者") }

  describe "AC-1: 何も選んでいないとき" do
    it "管理者の作業ツリーを開く" do
      get root_path

      expect(response).to redirect_to(admin_operations_path)
    end

    it "注意を出さない（AC-3）" do
      get root_path
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(flash).to be_empty
      document = Capybara.string(response.body)
      expect(document).to have_no_css(".flash-message")
      expect(document).to have_css("main h1", exact_text: "管理者：作業ツリー（マニュアル）")
      expect(document).to have_css('nav[aria-label="画面切り替え"] a[aria-current="page"]', count: 1, text: "作業ツリー（マニュアル）")
    end
  end

  describe "AC-2: スタッフを選んでいるとき" do
    before { patch operator_path, params: { user_id: nakamura.id } }

    it "スタッフの作業マニュアルを開く" do
      get root_path

      expect(response).to redirect_to(staff_operations_path)
    end

    it "注意を出さず、選んだ人のまま（AC-3）" do
      get root_path
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(flash).to be_empty
      document = Capybara.string(response.body)
      expect(document).to have_no_css(".flash-message")
      expect(document).to have_css("main h1", exact_text: "スタッフ：作業マニュアル")
      expect(document).to have_select("操作する人", selected: "中村 健太")
      expect(document).to have_css('nav[aria-label="画面切り替え"] a[aria-current="page"]', count: 1, text: "作業マニュアル")
      expect(response.body).not_to include("管理者の見立て", "▲", "▼", "▽", "◇")
    end
  end

  it "日本語・日本時間の設定になっている" do
    travel_to Time.utc(2026, 11, 1, 0, 30) do
      get root_path
      follow_redirect!

      expect(response.body).to include('<html lang="ja">')
      expect(I18n.default_locale).to eq(:ja)
      expect(Time.zone.name).to eq("Tokyo")
      expect(Time.current.hour).to eq(9)
    end
  end
end
