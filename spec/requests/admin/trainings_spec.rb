require "rails_helper"

RSpec.describe "研修画面（S-3）" do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }

  before { travel_to(Time.zone.local(2026, 11, 2, 10, 30)) }

  # 名前で読みやすくするため、作業ごとにレベルと見立てを指定してスキルを作る
  def skill_in(operation, level, assessment = nil, name:)
    user = User.find_by(name:) || create(:user, name:, sort_order: User.maximum(:sort_order).to_i + 1)
    create(:skill, operation:, user:, level:, admin_assessment: assessment)
    user
  end

  def plan(operation, trainee, trainer: admin, due_on: nil)
    create(:training, operation:, trainer:, trainee:, due_on:)
  end

  def page
    Capybara.string(response.body)
  end

  def card(name)
    page.find(".training-card", text: name)
  end

  def open_screen
    get admin_trainings_path
    expect(response).to have_http_status(:ok)
  end

  describe "AC-1: カードに出す作業" do
    it "レベル0・1の人か▼の人がいる作業だけがカードで並ぶ" do
      skill_in(create(:operation, name: "給与計算"), 1, name: "吉田")
      skill_in(create(:operation, name: "年末調整"), 3, :needs_training, name: "中村")
      skill_in(create(:operation, name: "入社手続き"), 2, name: "加藤")

      open_screen

      expect(page.all(".training-card-title").map(&:text)).to contain_exactly(
        a_string_including("給与計算"), a_string_including("年末調整")
      )
    end

    it "対象の作業がなければ「該当する作業はありません」と出る" do
      open_screen

      expect(page).to have_no_css(".training-card")
      expect(page).to have_text("該当する作業はありません")
    end
  end

  describe "AC-2: カードの上段と4列" do
    it "作業名と「日付｜教える人｜未研修｜研修予定」の4列が出る" do
      skill_in(create(:operation, name: "給与計算"), 1, name: "吉田")

      open_screen

      expect(card("給与計算").all(".training-column-label").map(&:text)).to eq %w[日付 教える人 未研修 研修予定]
    end

    it "できる人が1人以下のときだけ「できる人○人」が出る" do
      one = create(:operation, name: "給与計算")
      skill_in(one, 4, name: "山本")
      skill_in(one, 1, name: "吉田")
      two = create(:operation, name: "入社手続き")
      skill_in(two, 4, name: "山本")
      skill_in(two, 4, name: "中村")
      skill_in(two, 0, name: "吉田")

      open_screen

      expect(card("給与計算")).to have_css(".training-capable-count", exact_text: "できる人1人")
      expect(card("入社手続き")).to have_no_css(".training-capable-count")
    end

    # 見た目（色・大きさ・位置）は作業ツリーと同じ部品でそろえる。スキルマップの警告カード（.capable-warning）の
    # クラスを持つと、その見た目がまざって大きくずれるので、持たないことを確かめる
    it "「できる人○人」は作業ツリーと同じ部品で出し、スキルマップの警告カードのクラスを持たない" do
      zero = create(:operation, name: "労働保険の年度更新")
      skill_in(zero, 0, name: "吉田")
      one = create(:operation, name: "給与計算")
      skill_in(one, 4, name: "山本")
      skill_in(one, 1, name: "吉田")

      open_screen

      { "労働保険の年度更新" => "できる人0人", "給与計算" => "できる人1人" }.each do |name, text|
        badge = card(name).find(".training-capable-count", exact_text: text)
        expect(badge[:class].split).to include("operation-badge", "operation-badge-warning")
        expect(badge[:class].split).not_to include("capable-warning", "badge", "badge-warning")
        expect(card(name)).to have_no_css(".capable-warning")
      end
    end

    it "できる人の数え方は変えない：レベル4の◇・▼もできる人に数える（2人なら出ず、1人なら出る）" do
      two = create(:operation, name: "勤怠の締め")
      skill_in(two, 4, :backup_trainer, name: "中村")
      skill_in(two, 4, :needs_training, name: "高橋")
      one = create(:operation, name: "年末調整")
      skill_in(one, 4, :backup_trainer, name: "山本")
      skill_in(one, 0, name: "吉田")

      open_screen

      expect(card("勤怠の締め")).to have_no_css(".training-capable-count")
      expect(card("年末調整")).to have_css(".training-capable-count", exact_text: "できる人1人")
    end

    it "できる人が1人以下の作業のカードは、枠の色を変えて目立たせる" do
      zero = create(:operation, name: "労働保険の年度更新")
      skill_in(zero, 0, name: "吉田")
      one = create(:operation, name: "給与計算")
      skill_in(one, 4, name: "山本")
      skill_in(one, 1, name: "吉田")
      two = create(:operation, name: "入社手続き")
      skill_in(two, 4, name: "山本")
      skill_in(two, 4, name: "中村")
      skill_in(two, 0, name: "吉田")

      open_screen

      expect(card("労働保険の年度更新")[:class]).to include("training-card-caution")
      expect(card("給与計算")[:class]).to include("training-card-caution")
      expect(card("入社手続き")[:class]).not_to include("training-card-caution")
    end
  end

  describe "AC-3: 日付" do
    let(:operation) { create(:operation, name: "年末調整", season_note: "毎年11月中に準備") }
    let!(:yoshida) { skill_in(operation, 1, name: "吉田") }

    it "予定がない作業の日付は空で、時期の目安が横に出る" do
      open_screen

      expect(card("年末調整").find("input[type=date]").value).to be_blank
      expect(card("年末調整")).to have_css(".season-note", text: "毎年11月中に準備")
    end

    it "予定がある作業は、その期限が入る。14日以内ならオレンジになる" do
      plan(operation, yoshida, due_on: Date.new(2026, 11, 10))

      open_screen

      date = card("年末調整").find("input[type=date]")
      expect(date.value).to eq "2026-11-10"
      expect(date[:class]).to include("due-soon")
    end

    it "期限が15日以上先ならオレンジにしない" do
      plan(operation, yoshida, due_on: Date.new(2026, 11, 30))

      open_screen

      expect(card("年末調整").find("input[type=date]")[:class]).not_to include("due-soon")
    end
  end

  describe "AC-4: 教える人と未研修" do
    let(:operation) { create(:operation, name: "勤怠の締め") }

    before do
      skill_in(operation, 4, :backup_trainer, name: "中村")
      skill_in(operation, 3, :can_train, name: "小林")
      skill_in(operation, 4, name: "山本")
      skill_in(operation, 4, :can_train, name: "佐藤")      # 4▲：候補に入るが▲は出さない
      skill_in(operation, 4, :training_done, name: "田中") # 4▽：候補に入るが▽は出さない
      skill_in(operation, 3, :backup_trainer, name: "鈴木") # 3◇：候補に入らない
      skill_in(operation, 0, name: "吉田")
      skill_in(operation, 3, :needs_training, name: "加藤")
      skill_in(operation, 4, :needs_training, name: "高橋")
    end

    it "教える人が #58 の順で並び、▲・◇は今のレベルで意味があるときだけ出る。管理者はレベルなしで最後" do
      open_screen

      trainers = card("勤怠の締め").all(".trainer-chip").map { |chip| chip.text.squish }
      expect(trainers).to eq [ "4 山本", "4 佐藤", "4 田中", "3 小林 ▲", "4 中村 ◇", "管理者" ]
    end

    # 凡例（ページの上）は main 側で直すので、ここではカードの中だけを確かめる
    it "▲・◇ の説明（title）が「指導できる」「指導に不安あり」になっていて、古い名前は出ない" do
      open_screen

      card = card("勤怠の締め")
      expect(card.find(".trainer-chip", text: "小林").find(".assessment-mark")[:title]).to eq "指導できる"
      expect(card.find(".trainer-chip", text: "中村").find(".assessment-mark")[:title]).to eq "指導に不安あり"
      expect(card.native.to_html).not_to include("研修権限", "教えるのは後回し")
    end

    it "未研修に、レベル0・1と▼の人が並び、▼が名前の横に出る" do
      open_screen

      trainees = card("勤怠の締め").all(".trainee-chip").map { |chip| chip.text.squish }
      expect(trainees).to eq [ "0 吉田", "3 加藤 ▼", "4 高橋 ▼" ]
    end

    it "未研修の人がいなければ「対象者なし」と出る" do
      User.where(name: %w[吉田 加藤 高橋]).find_each { |user| plan(operation, user) }

      open_screen

      expect(card("勤怠の締め")).to have_no_css(".trainee-chip")
      expect(card("勤怠の締め")).to have_text("対象者なし")
    end
  end

  describe "AC-5: 絞り込み" do
    it "「すべて／指示が必要／指示済み」のボタンに件数が出て、カードに状態が付いている" do
      unassigned = create(:operation, name: "給与計算")
      skill_in(unassigned, 1, name: "吉田")
      assigned = create(:operation, name: "年末調整")
      plan(assigned, skill_in(assigned, 0, name: "加藤"))

      open_screen

      filters = page.all("[data-training-filter-target=button]").map { |button| button.text.squish }
      expect(filters).to eq [ "すべて 2", "指示が必要 1", "指示済み 1" ]
      expect(card("給与計算")["data-status"]).to eq "unassigned"
      expect(card("年末調整")["data-status"]).to eq "assigned"
      expect(card("給与計算")["data-needs-instruction"]).to eq "true"
      expect(card("年末調整")["data-needs-instruction"]).to eq "false"
    end
  end

  describe "研修予定の列" do
    it "保存済みの予定が「教える人 → 教わる人」と期限で出る。予定がなければ「予定なし」" do
      operation = create(:operation, name: "給与計算")
      yamamoto = skill_in(operation, 4, name: "山本")
      plan(operation, skill_in(operation, 1, name: "吉田"), trainer: yamamoto, due_on: Date.new(2026, 11, 30))
      plan(operation, skill_in(operation, 0, name: "加藤"), trainer: yamamoto)
      skill_in(create(:operation, name: "年末調整"), 0, name: "吉田")

      open_screen

      plans = card("給与計算").all(".plan-chip").map { |chip| chip.text.squish }
      expect(plans).to contain_exactly("山本 → 吉田 期限：2026/11/30", "山本 → 加藤 期限：未設定")
      expect(card("年末調整")).to have_text("予定なし")
    end
  end

  describe "AC-6・AC-7: 指示済みの研修" do
    let(:operation) { create(:operation, name: "給与計算") }
    let!(:yamamoto) { skill_in(operation, 4, name: "山本") }

    def assigned_list
      page.find("#assigned-trainings")
    end

    it "未完了の予定だけが出て、見出しに件数が出る" do
      plan(operation, skill_in(operation, 1, name: "吉田"), trainer: yamamoto)
      plan(operation, skill_in(operation, 0, name: "加藤")).update!(status: :done, done_on: Date.new(2026, 10, 1))

      open_screen

      expect(assigned_list).to have_css("h2", text: "指示済みの研修（1件）")
      expect(assigned_list.all(".assigned-training").size).to eq 1
      expect(assigned_list).to have_text("給与計算")
      expect(assigned_list).to have_text("山本 → 吉田")
    end

    it "確認状態が「管理者が担当」「教える人が確認済み」「教える人が未確認」で出る" do
      plan(operation, skill_in(operation, 1, name: "吉田"))
      plan(operation, skill_in(operation, 0, name: "加藤"), trainer: yamamoto).update!(status: :acknowledged)
      plan(operation, skill_in(operation, 0, name: "小林"), trainer: yamamoto)

      open_screen

      expect(assigned_list.find(".assigned-training", text: "吉田")).to have_text("管理者が担当")
      expect(assigned_list.find(".assigned-training", text: "加藤")).to have_text("教える人が確認済み")
      expect(assigned_list.find(".assigned-training", text: "小林")).to have_text("教える人が未確認")
    end

    it "教わる人がレベル3以上に申告したら「（本人がレベル3以上に申告済み）」が出る。▼の人には出ない" do
      yoshida = skill_in(operation, 1, name: "吉田")
      kato = skill_in(operation, 1, :needs_training, name: "加藤")
      plan(operation, yoshida, trainer: yamamoto)
      plan(operation, kato, trainer: yamamoto)
      Skill.find_by!(operation:, user: yoshida).update!(level: 3)
      Skill.find_by!(operation:, user: kato).update!(level: 4)

      open_screen

      expect(assigned_list.find(".assigned-training", text: "吉田")).to have_text("（本人がレベル3以上に申告済み）")
      expect(assigned_list.find(".assigned-training", text: "加藤")).to have_no_text("申告済み")
    end

    it "「教え終わった」ボタンは、管理者が担当の予定にだけ出る" do
      by_admin = plan(operation, skill_in(operation, 1, name: "吉田"))
      plan(operation, skill_in(operation, 0, name: "加藤"), trainer: yamamoto)

      open_screen

      admin_item = assigned_list.find(".assigned-training", text: "吉田")
      expect(admin_item).to have_css("form[action='#{training_completion_path(by_admin)}'] button", text: "教え終わった")
      expect(assigned_list.find(".assigned-training", text: "加藤")).to have_no_button("教え終わった")
    end

    it "「教え終わった」を押すと完了になり、一覧から消える" do
      by_admin = plan(operation, skill_in(operation, 1, name: "吉田"))

      post training_completion_path(by_admin), headers: { "HTTP_REFERER" => admin_trainings_path }
      follow_redirect!

      expect(by_admin.reload).to be_done
      expect(assigned_list).to have_css("h2", text: "指示済みの研修（0件）")
      expect(assigned_list).to have_no_css(".assigned-training")
    end

    it "予定がなければ、空のときの説明が出る" do
      skill_in(operation, 1, name: "吉田")

      open_screen

      expect(assigned_list).to have_css("h2", text: "指示済みの研修（0件）")
      expect(assigned_list).to have_text("まだありません")
    end
  end

  describe "下書きと「変更を保存」のしくみ（#61）" do
    let(:operation) { create(:operation, name: "給与計算") }
    let!(:yamamoto) { skill_in(operation, 4, name: "山本") }
    let!(:yoshida) { skill_in(operation, 1, name: "吉田") }
    let!(:kato) { skill_in(operation, 0, name: "加藤") }
    let!(:saved) { plan(operation, kato, trainer: yamamoto) }

    before { open_screen }

    it "画面が共通部品（unsaved-changes）と下書きのコントローラの内側にあり、移るときの確認の文言が付いている（AC-6）" do
      root = page.find(".training-layout")

      expect(root["data-controller"].split).to include("unsaved-changes", "training-draft", "training-filter")
      expect(root["data-unsaved-changes-confirm-message-value"]).to eq "変更は保存されませんがよろしいですか？"
    end

    it "「変更を保存」の枠は最初は隠れていて、中に「変更を保存」と「（まだ保存されていません!）」がある（AC-4）" do
      bar = page.find("[data-unsaved-changes-target=bar]", visible: :all)

      expect(bar[:hidden]).not_to be_nil
      expect(bar).to have_button("変更を保存", visible: :all)
      expect(bar.text(:all)).to include("（まだ保存されていません!）")
    end

    it "「変更を保存」のフォームは PATCH /admin/training_plan に送り、共通部品の確認を出さない印が付いている（AC-5）" do
      form = page.find("[data-unsaved-changes-target=bar] form", visible: :all)

      expect(form[:action]).to eq admin_training_plan_path
      expect(form).to have_field("_method", with: "patch", type: :hidden, visible: :all)
      expect(form["data-unsaved-changes-skip"]).not_to be_nil
    end

    it "教える人・未研修・研修予定のボタンに、下書きに使う id が付いている（AC-1〜3）" do
      card = card("給与計算")

      expect(card["data-operation-id"]).to eq operation.id.to_s
      expect(card.find(".trainer-chip", text: "山本")["data-trainer-id"]).to eq yamamoto.id.to_s
      expect(card.find(".trainer-chip", text: "管理者")["data-trainer-id"]).to eq admin.id.to_s
      expect(card.find(".trainee-chip", text: "吉田")["data-trainee-id"]).to eq yoshida.id.to_s
      expect(card.find(".plan-chip", text: "加藤")["data-training-id"]).to eq saved.id.to_s
      expect(card.find("input[type=date]")["data-initial-value"]).to eq ""
    end

    it "右の一覧の未完了の予定に、取り消しの下書きにする「取り消す」ボタンがある（スタッフが担当の予定にも）" do
      item = page.find("#assigned-trainings .assigned-training", text: "加藤")

      expect(item.find("button", text: "取り消す")["data-training-id"]).to eq saved.id.to_s
      expect(item).to have_no_button("教え終わった")
    end

    it "画面を Turbo のキャッシュから外し、「戻る」で下書きが残った画面を出さない（AC-6）" do
      expect(page).to have_css('meta[name="turbo-cache-control"][content="no-cache"]', visible: :all)
    end
  end

  it "作業や予定が増えても、DB への問い合わせの回数は変わらない" do
    count_queries = lambda do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get admin_trainings_path }
      queries.size
    end

    add_operation = lambda do |i|
      operation = create(:operation, name: "作業#{i}", season_note: "年1回")
      skill_in(operation, 4, :backup_trainer, name: "教える人#{i}")
      skill_in(operation, 3, :can_train, name: "▲の人#{i}")
      plan(operation, skill_in(operation, 0, name: "教わる人#{i}"), due_on: Date.new(2026, 11, 10))
      skill_in(operation, 3, :needs_training, name: "▼の人#{i}")
    end

    add_operation.call(0)
    count_queries.call # 初回だけ読み込まれるもの（翻訳・スキーマなど）を除くため、1回開いておく
    one = count_queries.call
    (1..3).each { |i| add_operation.call(i) }

    expect(count_queries.call).to eq one
  end

  it "スタッフとして開くと、スタッフの画面に戻される" do
    patch operator_path, params: { user_id: skill_in(create(:operation), 0, name: "吉田").id }

    get admin_trainings_path

    expect(response).to redirect_to(staff_operations_path)
  end
end
