require "rails_helper"

# 研修の主要な流れ（AGENTS.md の「System spec は主要な流れ1本だけ」）。
# #61 では、研修画面で研修を頼む（下書き →「変更を保存」）ところまでを書く。
# #64 で続きを足す：教える人に切り替えて、わたしのスキル（#63）で「教え終わった」→ 教わった人がレベル2になる
RSpec.describe "研修の流れ", :js do
  let!(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let!(:yoshida) { create(:user, name: "吉田", sort_order: 2) }
  let!(:kato) { create(:user, name: "加藤", sort_order: 3) }
  let!(:nakamura) { create(:user, name: "中村", sort_order: 4) }
  let!(:payroll) { create(:operation, name: "給与計算") }
  let!(:year_end) { create(:operation, name: "年末調整") }

  before do
    # 何も選んでいないときに部長として扱われるよう、管理者を用意しておく
    create(:user, :admin, name: "管理者", sort_order: 0)
    # 給与計算：できる人1人（山本）。未研修は吉田（1）・加藤（0）
    create(:skill, operation: payroll, user: yamamoto, level: 4)
    create(:skill, operation: payroll, user: yoshida, level: 1)
    create(:skill, operation: payroll, user: kato, level: 0)
    # 年末調整：できる人2人。未研修は加藤（0）。予定はない
    create(:skill, operation: year_end, user: yamamoto, level: 4)
    create(:skill, operation: year_end, user: nakamura, level: 4)
    create(:skill, operation: year_end, user: kato, level: 0)
  end

  def card(name)
    find(".training-card", text: name)
  end

  def card_titles
    all(".training-card-title").map { |title| title.text.squish }
  end

  def assigned_list
    find("#assigned-trainings")
  end

  # 主要な流れを1本の例でつなげて確かめる（#64 で続きを足す）ため、例の長さの上限は外す
  it "研修画面で下書きを作り、「変更を保存」で研修を頼める" do # rubocop:disable RSpec/ExampleLength
    # 1. 研修画面を開く。「変更を保存」は出ていない
    visit admin_trainings_path
    initial_titles = card_titles
    expect(page).to have_no_button("変更を保存")

    # 2. 予定がない作業の日付だけを変えても、「変更を保存」は出ない（AC-4）
    within(card("年末調整")) { fill_in "年末調整の研修期限", with: Date.new(2026, 12, 20) }
    expect(page).to have_no_button("変更を保存")

    # 3. 未研修の吉田を選んで「管理者」を押すと、下書きの予定ができて「変更を保存」が出る。右の一覧にはまだ出ない（AC-1・AC-4・AC-5）
    within(card("給与計算")) do
      find(".trainee-chip", text: "吉田").click
      find(".trainer-chip", text: "管理者").click

      expect(page).to have_css(".plan-chip", text: "管理者 → 吉田")
      expect(page).to have_no_css(".trainee-chip", text: "吉田")
      expect(page).to have_css(".trainee-chip", text: "加藤")
    end
    expect(page).to have_button("変更を保存")
    expect(page).to have_text("（まだ保存されていません!）")
    expect(assigned_list).to have_css("h2", text: "指示済みの研修（0件）")

    # 4. 下書きの予定を押すと消え、吉田が未研修に戻る。「変更を保存」も消える（AC-3・AC-4）
    within(card("給与計算")) do
      find(".plan-chip", text: "管理者 → 吉田").click

      expect(page).to have_no_css(".plan-chip")
      expect(page).to have_css(".trainee-chip", text: "吉田")
    end
    expect(page).to have_no_button("変更を保存")

    # 5. 誰も選ばずに「管理者」を押すと、残っている未研修の人全員の予定が1人1件ずつできる（AC-2）
    within(card("給与計算")) do
      find(".trainer-chip", text: "管理者").click

      expect(all(".plan-chip").map { |chip| chip.text.squish })
        .to contain_exactly(a_string_including("管理者 → 吉田"), a_string_including("管理者 → 加藤"))
      expect(page).to have_no_css(".trainee-chip")
    end

    # 6. 下書きを変えても、カードの並び順は変わらない（AC-7）
    expect(card_titles).to eq initial_titles

    # 7. 「変更を保存」を押すと、「指示済みの研修」に反映される（AC-5）
    click_button "変更を保存"

    expect(assigned_list).to have_css("h2", text: "指示済みの研修（2件）")
    expect(assigned_list).to have_text("管理者 → 吉田")
    expect(assigned_list).to have_text("管理者 → 加藤")
    expect(page).to have_no_button("変更を保存")
    expect(Training.unfinished.where(operation: payroll).pluck(:trainee_id, :status))
      .to contain_exactly([ yoshida.id, "acknowledged" ], [ kato.id, "acknowledged" ])
    expect(Training.where(operation: year_end)).to be_empty
  end
end
