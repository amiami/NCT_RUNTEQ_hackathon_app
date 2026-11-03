require "rails_helper"

RSpec.describe "わたしのスキル（S-6）の一覧（左の欄）" do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:kobayashi) { create(:user, name: "小林", sort_order: 1) }
  let(:entry) { create(:category, name: "入退社", sort_order: 1) }
  let(:payroll_category) { create(:category, name: "勤怠・給与", sort_order: 2) }

  def operation_in(category, name, sort_order:, version: 1)
    create(:operation, category:, name:, sort_order:).tap { |operation| create(:manual, operation:, version:) }
  end

  # 完了した研修予定を作る。作成時の教わる人の条件（レベル0・1）を満たすよう、いったんレベルを0にしてから戻す
  def done_training(operation, trainee)
    skill = Skill.find_by!(operation:, user: trainee)
    level = skill.level
    skill.update!(level: 0)
    create(:training, operation:, trainer: admin, trainee:).update!(status: :done, done_on: Date.new(2026, 10, 1))
    skill.update!(level:)
  end

  def open_as(user)
    patch operator_path, params: { user_id: user.id }
    get staff_skills_path
    expect(response).to have_http_status(:ok)
  end

  def page
    Capybara.string(response.body)
  end

  def list
    page.find("#my-skill-list")
  end

  def row(name)
    list.find(".my-skill-row", text: name)
  end

  describe "AC-1: レベル0〜4ごとの件数" do
    it "左の欄の一番上に、レベル0〜4ごとの件数が5つ出て、合計が自分のスキルの数と合う" do
      [ 4, 4, 2, 0 ].each_with_index do |level, index|
        create(:skill, operation: operation_in(entry, "作業#{index}", sort_order: index), user: kobayashi, level:)
      end

      open_as(kobayashi)

      counts = list.all(".my-level-count").map { |card| [ card["data-level"], card.find(".my-level-count-number").text.squish ] }
      expect(counts).to eq [ %w[0 1件], %w[1 0件], %w[2 1件], %w[3 0件], %w[4 2件] ]
      expect(list.first(".my-level-count").text).to include("未着手")
    end
  end

  describe "AC-2: 分類ごとの作業名とレベル（4段のバー）" do
    before do
      create(:skill, operation: operation_in(payroll_category, "給与計算", sort_order: 1), user: kobayashi, level: 2)
      create(:skill, operation: operation_in(entry, "退職手続き", sort_order: 2), user: kobayashi, level: 0)
      create(:skill, operation: operation_in(entry, "入社手続き", sort_order: 1), user: kobayashi, level: 4)
    end

    it "分類の並び順 → 作業の並び順で、分類ごとにまとまって出る" do
      open_as(kobayashi)

      expect(list.all(".my-skill-category-title").map(&:text)).to eq %w[入退社 勤怠・給与]
      entry_rows = list.find(".my-skill-category", text: "入退社").all(".my-skill-name").map(&:text)
      expect(entry_rows).to eq %w[入社手続き 退職手続き]
    end

    it "4段のバーはレベルの数だけ塗られ、「レベルN」が出る" do
      open_as(kobayashi)

      { "入社手続き" => 4, "給与計算" => 2, "退職手続き" => 0 }.each do |name, level|
        bar = row(name).find(".skill-bar", visible: :all)
        expect(bar["aria-hidden"]).to eq "true"
        expect(bar.all(".skill-bar-segment", visible: :all).size).to eq 4
        expect(bar.all(".skill-bar-segment-on", visible: :all).size).to eq level
        expect(row(name).find(".my-skill-level").text).to eq "レベル#{level}"
      end
    end
  end

  describe "AC-3: 「研修済み」「再確認」" do
    it "完了した研修があれば「研修済み」（レベル3以上でも）。なければ出ない" do
      trained = operation_in(entry, "給与計算", sort_order: 1)
      create(:skill, operation: trained, user: kobayashi, level: 3)
      done_training(trained, kobayashi)
      create(:skill, operation: operation_in(entry, "入社手続き", sort_order: 2), user: kobayashi, level: 4)

      open_as(kobayashi)

      expect(row("給与計算")).to have_css(".my-skill-badge-trained", text: "研修済み")
      expect(row("入社手続き")).to have_no_css(".my-skill-badge-trained")
    end

    it "「再確認」は、確認した版が古いときだけ。一度も確認していない・今の版を確認した作業には出ない" do
      create(:skill, operation: operation_in(entry, "古い版", sort_order: 1, version: 2), user: kobayashi, level: 1,
                     confirmed_version: 1)
      create(:skill, operation: operation_in(entry, "今の版", sort_order: 2, version: 2), user: kobayashi, level: 1,
                     confirmed_version: 2)
      create(:skill, operation: operation_in(entry, "未確認", sort_order: 3, version: 2), user: kobayashi, level: 0)

      open_as(kobayashi)

      expect(row("古い版")).to have_css(".operation-badge-revision", text: "再確認")
      expect(row("今の版")).to have_no_css(".operation-badge-revision")
      expect(row("未確認")).to have_no_css(".operation-badge-revision")
    end

    it "「研修済み」と「再確認」は1つの行に両方出ることがある" do
      both = operation_in(entry, "年末調整", sort_order: 1, version: 2)
      create(:skill, operation: both, user: kobayashi, level: 2, confirmed_version: 1)
      done_training(both, kobayashi)

      open_as(kobayashi)

      expect(row("年末調整")).to have_css(".my-skill-badge-trained", text: "研修済み")
      expect(row("年末調整")).to have_css(".operation-badge-revision", text: "再確認")
    end
  end

  describe "AC-4: 作業を押すと、作業マニュアル（S-5）のその作業へ移る" do
    it "行全体が、その作業の作業マニュアルへのリンクになっている" do
      operation = operation_in(entry, "入社手続き", sort_order: 1)
      create(:skill, operation:, user: kobayashi, level: 1)

      open_as(kobayashi)

      expect(row("入社手続き").tag_name).to eq "a"
      expect(row("入社手続き")[:href]).to eq staff_operations_path(operation_id: operation.id)
    end
  end

  describe "AC-5: 管理者の画面には出ない。管理者の見立てを表す値を出さない" do
    it "▲▼▽◇ の見立てがあるスキルでも、HTML（属性を含む）に見立ての記号・値の名前が出ない" do
      { "作業1" => [ 3, :can_train ], "作業2" => [ 3, :needs_training ],
        "作業3" => [ 3, :training_done ], "作業4" => [ 4, :backup_trainer ] }
        .each_with_index do |(name, (level, assessment)), index|
          create(:skill, operation: operation_in(entry, name, sort_order: index), user: kobayashi, level:,
                         admin_assessment: assessment)
        end

      open_as(kobayashi)

      expect(list.all(".my-skill-row").size).to eq 4
      expect(response.body).not_to include("▲", "▼", "▽", "◇", "管理者の見立て")
      expect(response.body).not_to include("can_train", "needs_training", "training_done", "backup_trainer",
                                           "admin_assessment")
    end

    it "管理者の画面には一覧が出ない" do
      create(:skill, operation: operation_in(entry, "入社手続き", sort_order: 1), user: kobayashi, level: 1)

      [ admin_operations_path, admin_skill_map_path, admin_trainings_path ].each do |path|
        get path
        expect(page).to have_no_css(".my-skill-row")
        expect(page).to have_no_css(".my-level-count")
      end
    end

    it "部長がスタッフの画面（わたしのスキル）を直接開いても、一覧は出ない" do
      create(:skill, operation: operation_in(entry, "入社手続き", sort_order: 1), user: kobayashi, level: 1)

      get staff_skills_path

      expect(page).to have_css("#my-skill-list")
      expect(page).to have_no_css(".my-skill-row")
      expect(page).to have_no_css(".my-level-count")
    end
  end

  describe "データが増えても、DB への問い合わせの回数は変わらない" do
    # 分類・作業（マニュアル第2版）・自分のスキル（第1版を確認＝再確認）・完了した研修を1つずつ足す
    def add_operation_of_kobayashi(index)
      operation = operation_in(create(:category, name: "分類#{index}", sort_order: 10 + index), "作業#{index}",
                               sort_order: 1, version: 2)
      create(:skill, operation:, user: kobayashi, level: 2, confirmed_version: 1)
      done_training(operation, kobayashi)
    end

    def count_queries
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get staff_skills_path }
      queries.size
    end

    it "分類・作業・スキル・完了した研修を増やしても、回数が同じ" do
      add_operation_of_kobayashi(0)
      patch operator_path, params: { user_id: kobayashi.id }
      count_queries # 初回だけ読み込まれるもの（翻訳など）を除くため、1回開いておく
      one = count_queries
      (1..3).each { |index| add_operation_of_kobayashi(index) }

      expect(count_queries).to eq one
    end
  end
end
