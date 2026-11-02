require "rails_helper"

RSpec.describe "わたしのスキル（S-6）の教える予定・教わる予定" do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let(:yoshida) { create(:user, name: "吉田", sort_order: 2) }
  let(:kato) { create(:user, name: "加藤", sort_order: 3) }
  let(:payroll) { create(:operation, name: "給与計算") }
  let(:year_end) { create(:operation, name: "年末調整") }

  before { travel_to(Time.zone.local(2026, 11, 2, 10, 30)) }

  def skill(operation, user, level, assessment = nil)
    create(:skill, operation:, user:, level:, admin_assessment: assessment)
  end

  def plan(operation, trainer:, trainee:, due_on: nil)
    create(:training, operation:, trainer:, trainee:, due_on:)
  end

  def complete(training, on: Date.new(2026, 10, 5))
    training.update!(status: :done, done_on: on)
  end

  def open_as(user)
    patch operator_path, params: { user_id: user.id }
    get staff_skills_path
    expect(response).to have_http_status(:ok)
  end

  def page
    Capybara.string(response.body)
  end

  def teaching
    page.find("#teaching-trainings")
  end

  def learning
    page.find("#learning-trainings")
  end

  def item(list, text)
    list.find(".my-training", text:)
  end

  it "左右2列で、左に #80 のわたしのスキルの一覧の場所、右に教える予定・教わる予定がある" do
    open_as(yamamoto)

    layout = page.find(".my-skills-layout")
    expect(layout).to have_css("#my-skill-list")
    expect(layout).to have_css("aside#my-trainings h2", text: "教える予定")
    expect(layout).to have_css("aside#my-trainings h2", text: "教わる予定")
  end

  it "予定がなければ、どちらも「いまはありません」と出る" do
    open_as(yamamoto)

    expect(teaching).to have_text("いまはありません")
    expect(learning).to have_text("いまはありません")
  end

  describe "教える予定" do
    before do
      skill(payroll, yamamoto, 4)
      skill(payroll, yoshida, 1)
      skill(payroll, kato, 0)
      skill(year_end, yamamoto, 4)
      skill(year_end, yoshida, 0)
    end

    it "自分が教える人の未完了の予定だけが、作業・相手・期限で、期限が近い順に出る（AC-1）" do
      plan(year_end, trainer: yamamoto, trainee: yoshida, due_on: Date.new(2026, 12, 20))
      plan(payroll, trainer: yamamoto, trainee: yoshida, due_on: Date.new(2026, 11, 30))
      complete(plan(payroll, trainer: yamamoto, trainee: kato))
      other = create(:user, name: "小林", sort_order: 4)
      skill(year_end, other, 0)
      plan(year_end, trainer: admin, trainee: other)

      open_as(yamamoto)

      items = teaching.all(".my-training")
      expect(items.map { |node| node.find(".my-training-operation").text }).to eq %w[給与計算 年末調整]
      expect(items.first).to have_text("教える相手：吉田")
      expect(items.first).to have_text("期限：2026/11/30")
      expect(teaching).to have_no_text("加藤")
      expect(teaching).to have_no_text("小林")
    end

    it "「教え終わった」は #62 の受け口に向いていて、押すと完了し、相手がレベル2になって、わたしのスキルに戻る（AC-2）" do
      training = plan(payroll, trainer: yamamoto, trainee: yoshida)
      open_as(yamamoto)

      form = item(teaching, "給与計算").find("form")
      expect(form[:action]).to eq training_completion_path(training)

      post training_completion_path(training), headers: { "HTTP_REFERER" => staff_skills_path }

      expect(response).to redirect_to(staff_skills_path)
      expect(training.reload).to be_done
      expect(Skill.find_by!(operation: payroll, user: yoshida).level).to eq 2
      follow_redirect!
      expect(page).to have_css(".flash-notice", text: "「教え終わった」にしました")
      expect(teaching).to have_no_css(".my-training")
    end

    it "相手がレベル3以上に申告済み（▼なし）なら「（本人がレベル3以上に申告済み）」が出る。▼の人（3▼・4▼）の予定には出ない（AC-4）" do
      plan(payroll, trainer: yamamoto, trainee: yoshida)
      plan(payroll, trainer: yamamoto, trainee: kato)
      Skill.find_by!(operation: payroll, user: yoshida).update!(level: 3)
      Skill.find_by!(operation: payroll, user: kato).update!(level: 4, admin_assessment: :needs_training)
      nakamura = create(:user, name: "中村", sort_order: 4)
      skill(year_end, nakamura, 3, :needs_training)
      plan(year_end, trainer: yamamoto, trainee: nakamura)

      open_as(yamamoto)

      expect(item(teaching, "吉田")).to have_text("（本人がレベル3以上に申告済み）")
      expect(item(teaching, "加藤")).to have_no_text("申告済み")
      expect(item(teaching, "中村")).to have_no_text("申告済み")
    end

    it "期限まで14日以内ならオレンジになる" do
      plan(payroll, trainer: yamamoto, trainee: yoshida, due_on: Date.new(2026, 11, 10))
      plan(year_end, trainer: yamamoto, trainee: yoshida, due_on: Date.new(2026, 11, 30))

      open_as(yamamoto)

      expect(item(teaching, "給与計算")).to have_css(".due-soon", text: "期限：2026/11/10")
      expect(item(teaching, "年末調整")).to have_no_css(".due-soon")
    end
  end

  describe "教わる予定" do
    before do
      skill(payroll, yamamoto, 4)
      skill(payroll, yoshida, 1)
      skill(year_end, yoshida, 0)
    end

    it "作業・教えてくれる人・期限が出る（AC-3）" do
      plan(payroll, trainer: yamamoto, trainee: yoshida, due_on: Date.new(2026, 11, 30))
      plan(year_end, trainer: admin, trainee: yoshida)

      open_as(yoshida)

      expect(item(learning, "給与計算")).to have_text("教えてくれる人：山本")
      expect(item(learning, "給与計算")).to have_text("期限：2026/11/30")
      expect(item(learning, "年末調整")).to have_text("教えてくれる人：管理者")
      expect(item(learning, "年末調整")).to have_text("期限：未設定")
    end

    it "完了すると「研修済みになりました」と、誰から・いつが出る（AC-3）" do
      complete(plan(payroll, trainer: yamamoto, trainee: yoshida), on: Date.new(2026, 10, 5))

      open_as(yoshida)

      expect(item(learning, "給与計算")).to have_text("研修済みになりました（山本から・2026/10/05）")
      expect(item(learning, "給与計算")).to have_no_text("教えてくれる人")
    end

    it "完了した予定は作業ごとに最新の1件。同じ作業で未完了の予定があれば、未完了の方だけ出る" do
      complete(plan(payroll, trainer: yamamoto, trainee: yoshida), on: Date.new(2026, 6, 1))
      complete(plan(payroll, trainer: admin, trainee: yoshida), on: Date.new(2026, 7, 1))
      complete(plan(year_end, trainer: admin, trainee: yoshida), on: Date.new(2026, 8, 1))
      plan(year_end, trainer: admin, trainee: yoshida)

      open_as(yoshida)

      expect(learning.all(".my-training", text: "給与計算").size).to eq 1
      expect(item(learning, "給与計算")).to have_text("研修済みになりました（管理者から・2026/07/01）")
      expect(learning.all(".my-training", text: "年末調整").size).to eq 1
      expect(item(learning, "年末調整")).to have_text("教えてくれる人：管理者")
    end

    it "未完了の予定が先に、完了した予定はそのあとに並ぶ" do
      complete(plan(payroll, trainer: yamamoto, trainee: yoshida))
      plan(year_end, trainer: admin, trainee: yoshida)

      open_as(yoshida)

      expect(learning.all(".my-training-operation").map(&:text)).to eq %w[年末調整 給与計算]
    end
  end

  it "「マニュアルを見る」は、作業マニュアル（S-5）のその作業に向いている（AC-5）" do
    skill(payroll, yamamoto, 4)
    skill(payroll, yoshida, 1)
    skill(year_end, yamamoto, 0)
    plan(payroll, trainer: yamamoto, trainee: yoshida)
    plan(year_end, trainer: admin, trainee: yamamoto)

    open_as(yamamoto)

    expect(item(teaching, "給与計算")).to have_link("マニュアルを見る", href: staff_operations_path(operation_id: payroll.id))
    expect(item(learning, "年末調整")).to have_link("マニュアルを見る", href: staff_operations_path(operation_id: year_end.id))
  end

  it "▼の人の予定・▽になった人・▲の人がいても、HTML に管理者の見立てを表す値を含めない（AC-6）" do
    skill(payroll, yamamoto, 3, :can_train)
    skill(payroll, yoshida, 3, :needs_training)
    skill(payroll, kato, 3, :needs_training)
    plan(payroll, trainer: yamamoto, trainee: yoshida)
    TrainingCompletion.new(training: plan(payroll, trainer: yamamoto, trainee: kato), by: yamamoto).save
    skill(year_end, yamamoto, 4, :backup_trainer)

    open_as(yamamoto)
    body = response.body

    expect(Skill.find_by!(operation: payroll, user: kato)).to be_training_done
    expect(body).not_to include("▲", "▼", "▽", "◇", "管理者の見立て")
    expect(body).not_to include("can_train", "needs_training", "training_done", "backup_trainer", "admin_assessment")
  end

  # 教える予定（相手が申告済み）・完了した教わる予定・未完了の教わる予定を、山本に1件ずつ足す
  def add_trainings_of_yamamoto(index)
    operation = create(:operation, name: "作業#{index}")
    trainee = create(:user, name: "教わる人#{index}", sort_order: 10 + index)
    skill(operation, yamamoto, 4)
    skill(operation, trainee, 0)
    plan(operation, trainer: yamamoto, trainee:)
    Skill.find_by!(operation:, user: trainee).update!(level: 3)
    %w[A B].each do |suffix|
      learning = create(:operation, name: "教わる作業#{suffix}#{index}")
      skill(learning, yamamoto, 0)
      training = plan(learning, trainer: admin, trainee: yamamoto)
      complete(training) if suffix == "A"
    end
  end

  def count_queries
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get staff_skills_path }
    queries.size
  end

  it "予定が増えても、DB への問い合わせの回数は変わらない" do
    add_trainings_of_yamamoto(0)
    patch operator_path, params: { user_id: yamamoto.id }
    count_queries # 初回だけ読み込まれるもの（翻訳など）を除くため、1回開いておく
    one = count_queries
    (1..3).each { |index| add_trainings_of_yamamoto(index) }

    expect(count_queries).to eq one
  end
end
