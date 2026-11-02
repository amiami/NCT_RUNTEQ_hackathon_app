require "rails_helper"

RSpec.describe "スキルマップのマスの詳細（管理者）" do
  let!(:admin) { create(:user, :admin, name: "管理者") }
  let(:yamamoto) { create(:user, name: "山本 直子") }
  let(:nakamura) { create(:user, name: "中村 健太") }
  let(:payroll) { create(:operation, name: "給与計算") }

  def document
    Capybara.string(response.body)
  end

  # マスの詳細は、スキルマップの表の上の Turbo Frame（skill_detail）に入る
  def detail
    document.find("turbo-frame#skill_detail")
  end

  # 教わる人として登録できるよう、教わる人のスキルはレベル0のときに研修を作る（研修の作成時の条件）
  def create_done_training(trainee_skill, trainer:, done_on:)
    create(:skill, user: trainer, operation: trainee_skill.operation, level: 4) unless trainer.admin?
    create(:training, operation: trainee_skill.operation, trainer:, trainee: trainee_skill.user, status: :done, done_on:)
  end

  describe "AC-1: 詳細を Turbo Frame で返す" do
    it "skill_detail の枠の中に、人の名前と作業名が出る" do
      skill = create(:skill, user: yamamoto, operation: payroll)

      get admin_skill_path(skill)

      expect(response).to have_http_status(:ok)
      expect(detail).to have_text("山本 直子")
      expect(detail).to have_text("給与計算")
    end
  end

  describe "今のレベル" do
    it "見出しの横に、レベルの数字（マスと同じ色）と名前が出る" do
      { 0 => "未着手", 3 => "先輩のもとでできる", 4 => "作業を最後まで1人でできる" }.each do |level, name|
        skill = create(:skill, operation: payroll, level:)

        get admin_skill_path(skill)

        level_area = detail.find(".skill-detail-level")
        expect(level_area).to have_css(".skill-level.skill-level-#{level}", exact_text: level.to_s)
        expect(level_area).to have_text(name)
      end
    end
  end

  describe "AC-2: マニュアル確認状況" do
    before { create(:manual, operation: payroll, version: 2) }

    it "3つのうち正しいものが出る" do
      { nil => "未確認", 1 => "改定後 未確認", 2 => "確認済み" }.each do |confirmed_version, text|
        skill = create(:skill, operation: payroll, confirmed_version:)

        get admin_skill_path(skill)

        expect(detail.find(".skill-detail-manual-status")).to have_text(text, exact: true, normalize_ws: true)
      end
    end
  end

  describe "AC-3: 研修" do
    def training_text
      detail.find(".skill-detail-training").text.squish
    end

    it "完了した研修があれば「済み（○○さんから・日付）」が出る（最新のもの）" do
      skill = create(:skill, user: nakamura, operation: payroll, level: 0)
      create_done_training(skill, trainer: create(:user, name: "小林 由美"), done_on: Date.new(2026, 6, 25))
      create_done_training(skill, trainer: yamamoto, done_on: Date.new(2026, 7, 24))
      skill.update!(level: 2)

      get admin_skill_path(skill)

      expect(training_text).to eq "済み（山本 直子さんから・2026/07/24）"
    end

    it "管理者が教えた研修は、名前に「さん」を付けない" do
      skill = create(:skill, user: nakamura, operation: payroll, level: 0)
      create_done_training(skill, trainer: admin, done_on: Date.new(2026, 6, 10))

      get admin_skill_path(skill)

      expect(training_text).to eq "済み（管理者から・2026/06/10）"
    end

    it "完了した研修がなく、レベル3以上なら「なし（自分で習得）」が出る" do
      skill = create(:skill, operation: payroll, level: 3)

      get admin_skill_path(skill)

      expect(training_text).to eq "なし（自分で習得）"
    end

    it "完了した研修がなく、レベル0〜2なら「まだ」が出る" do
      skill = create(:skill, operation: payroll, level: 2)

      get admin_skill_path(skill)

      expect(training_text).to eq "まだ"
    end
  end

  # 見立ては、ラジオボタンで今の値が選ばれた状態で出る（選び直すと下書きになる）
  describe "AC-4: 管理者の見立て" do
    def assessment
      detail.find(".skill-detail-assessment")
    end

    it "見立てがなければ「なし」が選ばれている" do
      skill = create(:skill, operation: payroll, level: 3)

      get admin_skill_path(skill)

      expect(assessment).to have_checked_field("なし")
    end

    it "今のレベルで意味のある見立ては、その値が選ばれている（説明は添えない）" do
      skill = create(:skill, operation: payroll, level: 3, admin_assessment: :can_train)

      get admin_skill_path(skill)

      expect(assessment).to have_checked_field("▲ 指導できる")
      expect(assessment).to have_no_css(".skill-detail-assessment-note")
    end

    {
      [ 4, :can_train ] => [ "▲ 指導できる", "レベル3になっても、教える人の候補に残ります" ],
      [ 3, :backup_trainer ] => [ "◇ 指導に不安あり", "レベル4になると、教える人の候補の後ろに並びます" ],
      [ 4, :training_done ] => [ "▽ 研修済み", "▼から研修を受け終えました（いまは普通のレベル4として扱います）" ]
    }.each do |(level, admin_assessment), (value, note)|
      it "#{level}#{value[0]} は、実際の値が選ばれていて、説明が出る" do
        skill = create(:skill, operation: payroll, level:, admin_assessment:)

        get admin_skill_path(skill)

        expect(assessment).to have_checked_field(value)
        expect(assessment).to have_css(".skill-detail-assessment-note", exact_text: note)
      end
    end
  end

  describe "見立ての選択肢（下書き）" do
    def assessment
      detail.find(".skill-detail-assessment")
    end

    def enabled_choices
      assessment.all("input[type='radio']:not([disabled])").map { |radio| radio.find(:xpath, "..").text.squish }
    end

    def disabled_choices
      assessment.all("input[type='radio'][disabled]").map { |radio| radio.find(:xpath, "..").text.squish }
    end

    it "レベル3なら、なし・▲・▼を選べて、◇は押せない。▽は出ない" do
      get admin_skill_path(create(:skill, operation: payroll, level: 3))

      expect(enabled_choices).to eq [ "なし", "▲ 指導できる", "▼ 要研修" ]
      expect(disabled_choices).to eq [ "◇ 指導に不安あり" ]
      expect(assessment).to have_no_field("▽ 研修済み")
    end

    it "レベル4なら、なし・◇を選べて、▲・▼は押せない" do
      get admin_skill_path(create(:skill, operation: payroll, level: 4))

      expect(enabled_choices).to eq [ "なし", "◇ 指導に不安あり" ]
      expect(disabled_choices).to eq [ "▲ 指導できる", "▼ 要研修" ]
    end

    it "レベル0〜2なら、なしだけを選べる" do
      get admin_skill_path(create(:skill, operation: payroll, level: 2))

      expect(enabled_choices).to eq [ "なし" ]
      expect(disabled_choices).to eq [ "▲ 指導できる", "▼ 要研修", "◇ 指導に不安あり" ]
    end

    it "今の値は、今のレベルで付けられなくても押せる（選び直すと下書きの取り消しになるため）" do
      get admin_skill_path(create(:skill, operation: payroll, level: 4, admin_assessment: :can_train))

      expect(enabled_choices).to eq [ "なし", "▲ 指導できる", "◇ 指導に不安あり" ]
      expect(disabled_choices).to eq [ "▼ 要研修" ]
    end

    it "▽は、今の値が▽のときだけ出る（「教え終わった」でしか付かないため）" do
      get admin_skill_path(create(:skill, operation: payroll, level: 3, admin_assessment: :training_done))

      expect(enabled_choices).to eq [ "なし", "▲ 指導できる", "▼ 要研修", "▽ 研修済み（▼から研修を受け終えた）" ]
      expect(assessment).to have_checked_field("▽ 研修済み")
    end

    it "選ぶと skill-map コントローラの下書きに入る（スキルの ID と元の見立てを渡す）" do
      skill = create(:skill, operation: payroll, level: 3, admin_assessment: :needs_training)

      get admin_skill_path(skill)

      choices = assessment.find("fieldset[data-skill-map-target='assessment']")
      expect(choices["data-skill-id"]).to eq skill.id.to_s
      expect(choices["data-original-assessment"]).to eq "needs_training"
      expect(choices.all("input[type='radio']").map { |radio| radio["data-action"] }.uniq).to eq [ "skill-map#chooseAssessment" ]
      expect(choices.all("input[type='radio']").map(&:value)).to eq [ "", "can_train", "needs_training", "backup_trainer" ]
    end
  end

  describe "AC-5: 別のマスの詳細" do
    it "別のスキルを開くと、そのスキルの内容に切り替わる" do
      create(:skill, user: yamamoto, operation: payroll, level: 4)
      other = create(:skill, user: nakamura, operation: create(:operation, name: "入社手続き"), level: 0)

      get admin_skill_path(other)

      expect(detail).to have_text("中村 健太")
      expect(detail).to have_text("入社手続き")
      expect(detail).to have_no_text("山本 直子")
      expect(detail).to have_no_text("給与計算")
    end
  end

  describe "スタッフのとき" do
    it "スタッフの画面に戻される" do
      skill = create(:skill, user: yamamoto, operation: payroll)
      patch operator_path, params: { user_id: yamamoto.id }

      get admin_skill_path(skill)

      expect(response).to redirect_to(staff_operations_path)
    end
  end
end
