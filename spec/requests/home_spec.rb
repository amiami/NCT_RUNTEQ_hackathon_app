require "rails_helper"

RSpec.describe "トップページ" do
  it "スタッフの作業マニュアルを表示し、対応するタブを強調する" do
    get root_path

    expect(response).to have_http_status(:ok)
    document = Capybara.string(response.body)
    expect(document).to have_css("header", text: I18n.t("app_name"))
    expect(document).to have_css("main h1", text: "作業マニュアル")
    expect(document).to have_css('nav[aria-label="画面切り替え"] a[aria-current="page"]', count: 1, text: "作業マニュアル")
    expect(response.body).not_to include("管理者の見立て", "▲", "▼", "▽", "◇")
  end

  it "日本語・日本時間の設定になっている" do
    travel_to Time.utc(2026, 11, 1, 0, 30) do
      get root_path

      expect(response.body).to include('<html lang="ja">')
      expect(I18n.default_locale).to eq(:ja)
      expect(Time.zone.name).to eq("Tokyo")
      expect(Time.current.hour).to eq(9)
    end
  end
end
