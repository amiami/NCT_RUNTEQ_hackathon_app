require "rails_helper"

RSpec.describe "shared/_tabs" do
  before do
    allow(view).to receive_messages(admin_page?: false, navigation_current?: false,
                                    operator_switch: { staff: true, selected_id: nil, candidates: [] })
  end

  def tab(label)
    Capybara.string(rendered).find_link(label)
  end

  it "渡した件数をそれぞれのタブに表示する" do
    render partial: "shared/tabs", locals: { training_count: 3, unread_count: 7 }

    expect(tab("わたしのスキル")).to have_css(".notification-count", exact_text: "3")
    expect(tab("改訂のお知らせ")).to have_css(".notification-count", exact_text: "7")
    expect(tab("作業マニュアル")).to have_no_css(".notification-count")
  end

  it "0件のタブにはバッジを出さない（AC-4）" do
    render partial: "shared/tabs", locals: { training_count: 0, unread_count: 2 }

    expect(tab("わたしのスキル")).to have_no_css(".notification-count")
    expect(tab("改訂のお知らせ")).to have_css(".notification-count", exact_text: "2")
  end

  it "件数を渡さない・nil のときもバッジを出さず、99 も出さない（AC-5）" do
    render partial: "shared/tabs", locals: { unread_count: nil }

    expect(Capybara.string(rendered)).to have_no_css(".notification-count")
    expect(rendered).not_to include("99")
  end

  it "ヘッダーから受け取った件数をタブへ渡す" do
    render partial: "shared/header", locals: { training_count: 5, unread_count: 8 }

    expect(tab("わたしのスキル")).to have_css(".notification-count", exact_text: "5")
    expect(tab("改訂のお知らせ")).to have_css(".notification-count", exact_text: "8")
  end

  context "管理者の画面" do
    before { allow(view).to receive(:admin_page?).and_return(true) }

    it "スキルマップだけに件数を出し、スタッフ用の件数を混ぜない" do
      render partial: "shared/tabs", locals: { skill_map_count: 4, training_count: 3, unread_count: 7 }

      expect(tab("スキルマップ")).to have_css(".notification-count", exact_text: "4")
      expect(Capybara.string(rendered)).to have_css(".notification-count", count: 1)
    end

    it "スキルマップの件数が0・nil ならバッジを出さない" do
      [ 0, nil ].each do |count|
        render partial: "shared/tabs", locals: { skill_map_count: count }

        expect(tab("スキルマップ")).to have_no_css(".notification-count")
      end
    end

    it "ヘッダーから管理者の件数を受け取る" do
      render partial: "shared/header", locals: { skill_map_count: 4 }

      expect(tab("スキルマップ")).to have_css(".notification-count", exact_text: "4")
    end
  end
end
