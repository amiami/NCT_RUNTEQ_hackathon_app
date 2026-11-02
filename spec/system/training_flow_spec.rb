require "rails_helper"

# 研修の流れ（AGENTS.md の「System spec は主要な流れ1本だけ」）。
# - 下書きの動き：研修画面で下書きを作り、「変更を保存」で研修を頼む（#61。テスト用のデータ）
# - 研修の主要な流れ：研修を頼む →「変更を保存」→ 教える人がわたしのスキルで「教え終わった」→ 教わった人がレベル2（#64。seeds と同じデータ）
RSpec.describe "研修の流れ", :js do
  def card(name)
    find(".training-card", text: name)
  end

  def card_titles
    all(".training-card-title").map { |title| title.text.squish }
  end

  def assigned_list
    find("#assigned-trainings")
  end

  def click_tab(label)
    within('nav[aria-label="画面切り替え"]') { click_link label }
  end

  # 右上の切り替えで、操作する人をスタッフに切り替える（画面の操作）。
  # 部長のときはプルダウンがないので、先に「スタッフ」を押してから、プルダウンで選んで「切り替え」を押す。
  # #126 で切り替えがスタッフ名のボタンになったら、ここを直す
  def switch_operator_to(name)
    within(%([role="group"][aria-label="#{I18n.t('operators.switch_label')}"])) do
      click_button I18n.t("navigation.roles.staff") unless has_select?(I18n.t("operators.label"), wait: 0)
      select name, from: I18n.t("operators.label")
      click_button I18n.t("operators.submit")
    end
    expect(page).to have_select(I18n.t("operators.label"), selected: name)
  end

  context "下書きの動き（テスト用のデータ）" do
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

    # 下書きの動きを1本の例でつなげて確かめるため、例の長さの上限は外す
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

  # seeds が変わっても原因が分かりやすいよう、テストの前提にしている値だけを最初に確かめる。
  # マニュアルの手順の文や、スタッフの人数・作業の数など、この流れに関係ない値は確かめない
  context "研修の主要な流れ（seeds と同じデータ）" do
    let(:payroll) { Operation.find_by!(name: "給与計算") }
    let(:yamamoto) { User.find_by!(name: "山本 直子") }
    let(:yoshida) { User.find_by!(name: "吉田 あかり") }

    before do
      travel_to(Time.zone.local(2026, 11, 2, 10, 30))
      load Rails.root.join("db/seeds.rb")
    end

    def skill_of(user)
      Skill.find_by!(operation: payroll, user:)
    end

    # 給与計算で、未研修の吉田を選び、日付を入れて山本を押す（下書き）
    def draft_training_from_yamamoto_to_yoshida
      within(card("給与計算")) do
        fill_in "給与計算の研修期限", with: Date.new(2026, 11, 20)
        find(".trainee-chip", text: "吉田 あかり").click
        find(".trainer-chip", text: "山本 直子").click

        expect(page).to have_css(".plan-chip", text: "山本 直子 → 吉田 あかり")
        expect(page).to have_css(".plan-chip", text: "期限：2026/11/20")
      end
      expect(page).to have_button("変更を保存")
    end

    # 主要な流れを1本の例でつなげて確かめるため、例の長さの上限は外す
    it "研修を頼んで「変更を保存」し、教える人が「教え終わった」を押すと、教わった人がレベル2になる" do # rubocop:disable RSpec/ExampleLength
      # 0. テストの前提（seeds）：給与計算の山本はレベル4、吉田はレベル1で、給与計算に未完了の予定はない
      expect(skill_of(yamamoto).level).to eq 4
      expect(skill_of(yoshida).level).to eq 1
      expect(Training.unfinished.where(operation: payroll)).to be_empty

      # --- AC-2：保存せずに別のタブへ移ると、戻っても下書きが残っていない ---
      # 1. 部長で研修画面を開き、山本 → 吉田 の下書きを作る
      visit admin_trainings_path
      draft_training_from_yamamoto_to_yoshida

      # 2. 保存せずに「スキルマップ」タブへ移る。共通部品の確認を受け入れて移る
      accept_confirm("変更は保存されませんがよろしいですか？") { click_tab "スキルマップ" }
      expect(page).to have_current_path(admin_skill_map_path)

      # 3. 「研修」タブで戻ると、下書きは残っていない（予定・日付・「変更を保存」なし。DB にもない）
      click_tab "研修"
      within(card("給与計算")) do
        expect(page).to have_no_css(".plan-chip")
        expect(page).to have_css(".trainee-chip", text: "吉田 あかり")
        expect(find_field("給与計算の研修期限").value).to eq ""
      end
      expect(page).to have_no_button("変更を保存")
      expect(assigned_list).to have_css("h2", text: "指示済みの研修（0件）")
      expect(Training.unfinished.where(operation: payroll)).to be_empty

      # --- AC-1：研修を頼む →「変更を保存」→ 教え終わった → レベル2 ---
      # 4. もう一度下書きを作り、「変更を保存」で「指示済みの研修」に入る
      draft_training_from_yamamoto_to_yoshida
      click_button "変更を保存"
      expect(assigned_list).to have_css(".assigned-training", text: "山本 直子 → 吉田 あかり")
      expect(assigned_list).to have_text("期限：2026/11/20")

      # 5. 教える人（山本）に切り替え、わたしのスキルの教える予定で「教え終わった」を押す
      switch_operator_to("山本 直子")
      click_tab "わたしのスキル"
      within("#teaching-trainings .my-training", text: "給与計算") do
        expect(page).to have_text("教える相手：吉田 あかり")
        expect(page).to have_text("期限：2026/11/20")
        click_button "教え終わった"
      end
      expect(page).to have_css(".flash-notice", text: "「教え終わった」にしました")
      expect(find("#teaching-trainings")).to have_no_css(".my-training", text: "給与計算")

      # 6. 教わった人（吉田）に切り替えると、教わる予定に「研修済みになりました」が出る
      switch_operator_to("吉田 あかり")
      click_tab "わたしのスキル"
      within("#learning-trainings .my-training", text: "給与計算") do
        expect(page).to have_text("研修済みになりました（山本 直子から・2026/11/02）")
        click_link "マニュアルを見る"
      end

      # 7. 作業マニュアルの作業ツリーで、吉田の給与計算のレベルが2になっている（画面と DB）
      expect(find(".operation-tree-link", text: "給与計算")).to have_css(".skill-level", text: /2\z/)
      expect(skill_of(yoshida).level).to eq 2
      expect(SkillLevelChange.where(skill: skill_of(yoshida)).pluck(:reason, :from_level, :to_level, :changed_by_id))
        .to eq [ [ "trained", 1, 2, yamamoto.id ] ]
    end
  end
end
