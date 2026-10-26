require "rails_helper"

RSpec.describe "トップページ" do
  it "表示できる" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app_name"))
  end

  it "日本語・日本時間の設定になっている" do
    travel_to Time.utc(2026, 11, 1, 0, 30) do # UTC 0:30 = 日本時間 9:30
      get root_path

      expect(response.body).to include("2026/11/01 09:30")
    end
  end
end
