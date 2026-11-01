require "rails_helper"

RSpec.describe "layouts/application" do
  [
    [ "staff/operations/index", false, { training_count: 0, unread_count: 8 }, { "わたしのスキル" => "0", "改訂のお知らせ" => "8" } ],
    [ "admin/operations/index", true, { skill_map_count: 4 }, { "スキルマップ" => "4" } ]
  ].each do |template, admin, counts, badges|
    it "#{admin ? '管理者' : 'スタッフ'}画面でnavigation_countsの件数を共通ヘッダー1つへ渡す" do
      allow(view).to receive_messages(application_page?: true, admin_page?: admin, navigation_current?: false, navigation_counts: counts,
                                      operator_switch: { staff: !admin, selected_id: nil, candidates: [] })

      render template: template, layout: "layouts/application"

      document = Capybara.string(rendered)
      expect(document).to have_css("header", count: 1)
      badges.each do |label, count|
        expect(document.find_link(label)).to have_css(".notification-count", exact_text: count)
      end
    end
  end
end
