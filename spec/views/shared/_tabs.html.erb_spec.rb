require "rails_helper"

RSpec.describe "shared/_tabs" do
  before do
    allow(view).to receive_messages(admin_page?: false, navigation_current?: false)
  end

  def badge_for(label)
    Capybara.string(rendered).find_link(label).find(".notification-count").text
  end

  it "件数を省略すると両方の通知に99を表示する" do
    render partial: "shared/tabs"

    expect(badge_for("わたしのスキル")).to eq("99")
    expect(badge_for("改訂のお知らせ")).to eq("99")
    expect(Capybara.string(rendered).find_link("作業マニュアル")).to have_no_css(".notification-count")
  end

  it "渡した件数をそれぞれのタブに表示する" do
    render partial: "shared/tabs", locals: { training_count: 3, unread_count: 7 }

    expect(badge_for("わたしのスキル")).to eq("3")
    expect(badge_for("改訂のお知らせ")).to eq("7")
  end

  it "0を99に置き換えない" do
    render partial: "shared/tabs", locals: { training_count: 0, unread_count: 0 }

    expect(badge_for("わたしのスキル")).to eq("0")
    expect(badge_for("改訂のお知らせ")).to eq("0")
  end

  it "未指定またはnilの件数だけを99にする" do
    render partial: "shared/tabs", locals: { training_count: 2, unread_count: nil }

    expect(badge_for("わたしのスキル")).to eq("2")
    expect(badge_for("改訂のお知らせ")).to eq("99")
  end

  it "一方だけを渡した場合も独立して既定値を使う" do
    render partial: "shared/tabs", locals: { unread_count: 4 }

    expect(badge_for("わたしのスキル")).to eq("99")
    expect(badge_for("改訂のお知らせ")).to eq("4")
  end

  it "ヘッダーから受け取った件数をタブへ渡す" do
    render partial: "shared/header", locals: { training_count: 5, unread_count: 8 }

    expect(badge_for("わたしのスキル")).to eq("5")
    expect(badge_for("改訂のお知らせ")).to eq("8")
  end

  it "管理者はスキルマップだけに99を表示し、スタッフ用件数を混ぜない" do
    allow(view).to receive(:admin_page?).and_return(true)

    render partial: "shared/tabs", locals: { training_count: 3, unread_count: 7 }

    expect(badge_for("スキルマップ")).to eq("99")
    expect(Capybara.string(rendered)).to have_css(".notification-count", count: 1)
  end

  [ nil, 0, 6 ].each do |count|
    it "管理者の件数に#{count.inspect}を渡した場合に正しく表示する" do
      allow(view).to receive(:admin_page?).and_return(true)

      render partial: "shared/tabs", locals: { skill_map_count: count }

      expect(badge_for("スキルマップ")).to eq(count.nil? ? "99" : count.to_s)
    end
  end

  it "ヘッダーから管理者の件数を受け取る" do
    allow(view).to receive(:admin_page?).and_return(true)

    render partial: "shared/header", locals: { skill_map_count: 4 }

    expect(badge_for("スキルマップ")).to eq("4")
  end
end
