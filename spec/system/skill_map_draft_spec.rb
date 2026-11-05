require "rails_helper"

# スキルマップの見立ての下書き（画面の中だけで動くので System spec で確かめる。AGENTS.md の「同じファイルにもう1本まで」の範囲）。
# 「変更を保存」の近くに、まだ保存していない見立ての件数を出す
RSpec.describe "スキルマップの見立ての下書き", :js do
  let!(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let!(:kato) { create(:user, name: "加藤", sort_order: 2) }
  let!(:payroll) { create(:operation, name: "給与計算") }
  let!(:yamamoto_skill) { create(:skill, user: yamamoto, operation: payroll, level: 3) }
  let!(:kato_skill) { create(:skill, user: kato, operation: payroll, level: 3) }

  before do
    # 何も選んでいないときに部長として扱われるよう、管理者を用意しておく
    create(:user, :admin, name: "管理者", sort_order: 0)
  end

  def open_detail(skill)
    find("#skill_#{skill.id} a.skill-map-cell").click
    expect(page).to have_css(".skill-detail-title", text: skill.user.name)
  end

  def choose_assessment(label)
    within(".skill-detail") { choose label }
  end

  # 下書きの増え方・減り方を1本の例でつなげて確かめるため、例の長さの上限は外す
  it "見立てを選ぶと件数が増え、元の見立てを選び直すと減る" do # rubocop:disable RSpec/ExampleLength
    visit admin_skill_map_path
    expect(page).to have_no_button("変更を保存")

    # 1. 山本さんのマスで▲を選ぶと、「変更を保存（1件）」と「（まだ保存されていません!）」が出る（AC-2）
    open_detail(yamamoto_skill)
    choose_assessment "▲ 指導できる"
    expect(page).to have_button("変更を保存（1件）", exact: true)
    expect(page).to have_text("（まだ保存されていません!）")

    # 2. 別のマス（加藤さん）で▼を選ぶと2件になる。詳細が入れ替わっても「変更を保存」は消えない（AC-3）
    open_detail(kato_skill)
    choose_assessment "▼ 要研修"
    expect(page).to have_button("変更を保存（2件）", exact: true)

    # 3. 山本さんのマスに戻って元の見立て（なし）を選び直すと、1件に減る（AC-3）
    open_detail(yamamoto_skill)
    choose_assessment "なし"
    expect(page).to have_button("変更を保存（1件）", exact: true)

    # 4. 加藤さんも元に戻すと下書きがなくなり、「変更を保存」が消える（AC-6）
    open_detail(kato_skill)
    choose_assessment "なし"
    expect(page).to have_no_button("変更を保存")
  end
end
