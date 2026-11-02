require "rails_helper"

RSpec.describe "タブの件数" do
  let!(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let!(:yoshida) { create(:user, name: "吉田", sort_order: 2) }
  let(:payroll) { create(:operation, name: "給与計算") }
  let(:year_end) { create(:operation, name: "年末調整") }

  def tab(label)
    Capybara.string(response.body).find_link(label)
  end

  before do
    # 何も選んでいないときに部長として扱われるよう、管理者を用意しておく
    create(:user, :admin, name: "管理者", sort_order: 0)
    # 給与計算：山本（4）が吉田（1）に教える予定。できる人は1人
    create(:skill, operation: payroll, user: yamamoto, level: 4)
    create(:skill, operation: payroll, user: yoshida, level: 1)
    create(:training, operation: payroll, trainer: yamamoto, trainee: yoshida)
    # 年末調整：改定で第2版。山本・吉田とも第1版を確認しただけ（未確認）。できる人は0人
    create(:manual, operation: year_end, version: 2)
    create(:skill, operation: year_end, user: yamamoto, level: 3, confirmed_version: 1)
    create(:skill, operation: year_end, user: yoshida, level: 2, confirmed_version: 1)
  end

  context "スタッフのとき" do
    before { patch operator_path, params: { user_id: yoshida.id } }

    it "わたしのスキルに完了していない予定の件数、改訂のお知らせに未確認の件数が出る（AC-1・AC-2）" do
      get staff_operations_path

      expect(tab("わたしのスキル")).to have_css(".notification-count", exact_text: "1")
      expect(tab("改訂のお知らせ")).to have_css(".notification-count", exact_text: "1")
    end

    it "教える予定も、わたしのスキルの件数に入る（AC-1）" do
      patch operator_path, params: { user_id: yamamoto.id }
      get staff_skills_path

      expect(tab("わたしのスキル")).to have_css(".notification-count", exact_text: "1")
    end

    it "0件のタブにはバッジが出ない（AC-4）" do
      Training.update_all(status: Training.statuses[:done], done_on: Date.new(2026, 10, 1))
      get staff_operations_path

      expect(tab("わたしのスキル")).to have_no_css(".notification-count")
      expect(tab("改訂のお知らせ")).to have_css(".notification-count", exact_text: "1")
    end

    it "スタッフ画面の HTML に、管理者の見立てを表す値を含めない" do
      Skill.find_by!(operation: year_end, user: yamamoto).update!(admin_assessment: :needs_training)
      get staff_operations_path

      expect(response.body).not_to include("needs_training", "管理者の見立て", "▼")
    end
  end

  context "部長のとき" do
    it "スキルマップに、できる人が1人以下の作業の数が出る（0人の作業も数える。AC-3）" do
      get admin_operations_path

      expect(tab("スキルマップ")).to have_css(".notification-count", exact_text: "2")
      expect(Capybara.string(response.body)).to have_css(".notification-count", count: 1)
    end

    it "できる人が2人以上の作業は数えない" do
      create(:skill, operation: payroll, user: create(:user, name: "中村", sort_order: 3), level: 4)
      get admin_operations_path

      expect(tab("スキルマップ")).to have_css(".notification-count", exact_text: "1")
    end
  end

  it "どの画面にも「99」の仮表示が出ない（AC-5）" do
    [ admin_operations_path, admin_skill_map_path ].each do |path|
      get path
      expect(Capybara.string(response.body)).to have_no_css(".notification-count", exact_text: "99")
    end
    patch operator_path, params: { user_id: yoshida.id }
    [ staff_operations_path, staff_skills_path, staff_manual_revisions_path ].each do |path|
      get path
      expect(Capybara.string(response.body)).to have_no_css(".notification-count", exact_text: "99")
    end
  end
end
