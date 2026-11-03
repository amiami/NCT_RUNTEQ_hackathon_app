require "rails_helper"

# スタッフ画面に管理者の見立てが出ないこと、スタッフが見立てを付けられないことを、1か所でまとめて確かめる。
# 見立ての4種類（▲▼▽◇）と、▼の人の研修予定（教える側・教わる側）がそろったデータで、スタッフが開ける画面と操作をすべて見る。
# 「研修済み」は、わたしのスキルのバッジと見立ての「▽ 研修済み」で同じ言葉なので、文字ではなく記号と値の名前で確かめる。
# （各機能の Request spec にも同じ確かめがあるが、そちらは機能ごとの念のための確認として残している）
RSpec.describe "スタッフ画面に管理者の見立てが出ない" do
  # スタッフ画面の返事に含まれてはいけないもの：見立ての記号・enum の名前・カラム名・「管理者の見立て」
  def forbidden
    [ "▲", "▼", "▽", "◇",
      "can_train", "needs_training", "training_done", "backup_trainer", "admin_assessment",
      "管理者の見立て" ]
  end

  # Turbo がフォームを送るときの Accept（Turbo Stream を受け取れる）と、JSON
  def turbo_stream = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  def json = "application/json"

  let(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let(:kato) { create(:user, name: "加藤", sort_order: 2) }
  let(:category) { create(:category, name: "勤怠・給与", sort_order: 1) }
  let(:payroll) { operation("給与計算", 1) }
  let(:year_end) { operation("年末調整", 2) }
  let(:santei) { operation("算定基礎届", 3) }
  let(:attendance) { operation("勤怠の締め", 4) }

  def operations = [ payroll, year_end, santei, attendance ]

  # 加藤（▼）が山本から給与計算を教わる、未完了の予定（before で作る）
  def training_for_kato = Training.find_by!(operation: payroll, trainee: kato)

  # 作業とマニュアル（第2版。改訂履歴つき）を作る。第1版を確認した人には「再確認」が出る
  def operation(name, sort_order)
    create(:operation, category:, name:, sort_order:).tap do |created|
      manual = create(:manual, operation: created, version: 2)
      create(:manual_revision, manual:, user: admin, version: 2)
    end
  end

  def skill_of(user, operation)
    Skill.find_by!(user:, operation:)
  end

  before do
    # 山本：給与計算 4（加藤に教える）、年末調整 3▲（再確認）、算定基礎届 4◇、勤怠の締め 3▽（研修済み）
    create(:skill, user: yamamoto, operation: payroll, level: 4, confirmed_version: 2)
    create(:skill, user: yamamoto, operation: year_end, level: 3, admin_assessment: :can_train, confirmed_version: 1)
    create(:skill, user: yamamoto, operation: santei, level: 4, admin_assessment: :backup_trainer, confirmed_version: 2)
    # 勤怠の締めは、▼のときに管理者から教わり終えて▽になり、そのあと3を申告した
    create(:skill, user: yamamoto, operation: attendance, level: 1, admin_assessment: :needs_training)
    TrainingCompletion.new(training: create(:training, operation: attendance, trainer: admin, trainee: yamamoto),
                           by: admin).save
    skill_of(yamamoto, attendance).update!(level: 3)
    # 加藤：給与計算 3▼（山本から教わる予定。予定を作るときの条件を満たすよう、レベル1で作ってから3にする）、
    # 年末調整 1（再確認）、算定基礎届 0（未確認）
    create(:skill, user: kato, operation: payroll, level: 1, admin_assessment: :needs_training, confirmed_version: 2)
    create(:training, operation: payroll, trainer: yamamoto, trainee: kato)
    skill_of(kato, payroll).update!(level: 3)
    create(:skill, user: kato, operation: year_end, level: 1, confirmed_version: 1)
    create(:skill, user: kato, operation: santei, level: 0)
  end

  def operate_as(user)
    patch operator_path, params: { user_id: user.id }
  end

  def expect_no_assessment(body = response.body)
    forbidden.each { |value| expect(body).not_to include(value), "「#{value}」が含まれている" }
  end

  def document
    Capybara.string(response.body)
  end

  # スタッフが開ける画面（作業マニュアルは作業ごと）
  def staff_paths
    [ staff_operations_path, *operations.map { |op| staff_operations_path(operation_id: op.id) },
      staff_skills_path, staff_manual_revisions_path ]
  end

  it "テストの前提：見立ての4種類と、▼の人の未完了の予定がそろっている" do
    expect(Skill.where(user: [ yamamoto, kato ]).pluck(:admin_assessment).compact.uniq)
      .to contain_exactly("can_train", "needs_training", "training_done", "backup_trainer")
    expect(training_for_kato.reload).not_to be_done
    expect(skill_of(kato, payroll)).to be_needs_training
  end

  describe "AC-1・AC-3：スタッフ画面の HTML に含まれない（▼の人の予定があるときも）" do
    [ :yamamoto, :kato ].each do |viewer|
      it "#{viewer == :yamamoto ? '山本（▼の人に教える）' : '加藤（▼で教わる）'}が開ける画面すべてに含まれない" do
        operate_as(public_send(viewer))

        staff_paths.each do |path|
          get path
          expect(response).to have_http_status(:ok), path
          expect_no_assessment
        end
      end
    end

    it "山本の画面には、▼の加藤への教える予定・研修済み・再確認・自己申告のボタンが実際に出ている（そのうえで含まれない）" do
      operate_as(yamamoto)

      get staff_skills_path
      expect(document.find("#teaching-trainings")).to have_text("教える相手：加藤")
      expect(document.find(".my-skill-row", text: "勤怠の締め")).to have_text("研修済み")
      expect(document.find(".my-skill-row", text: "年末調整")).to have_text("再確認")
      expect_no_assessment

      get staff_operations_path(operation_id: year_end.id)
      expect(document).to have_button("最後まで1人でできる（レベル4）")
      expect_no_assessment
    end

    it "加藤の画面には、▼の自分が教わる予定と、マニュアルの確認のボタンが実際に出ている（そのうえで含まれない）" do
      operate_as(kato)

      get staff_skills_path
      expect(document.find("#learning-trainings")).to have_text("教えてくれる人：山本")
      expect_no_assessment

      get staff_operations_path(operation_id: santei.id)
      expect(document).to have_button("マニュアルを確認した")
      expect_no_assessment
    end

    it "▼の加藤が教わり終えて▽になったあとも、山本・加藤の画面に含まれない" do
      operate_as(yamamoto)
      post training_completion_path(training_for_kato)
      expect(skill_of(kato, payroll)).to be_training_done

      [ yamamoto, kato ].each do |viewer|
        operate_as(viewer)
        staff_paths.each do |path|
          get path
          expect_no_assessment
        end
      end
    end
  end

  describe "AC-2：Turbo Stream と JSON の返事にも含まれない" do
    before { operate_as(kato) }

    it "スタッフの画面を Turbo Stream つきで開くと HTML が返り、含まれない" do
      staff_paths.each do |path|
        get path, headers: { "Accept" => turbo_stream }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq "text/html"
        expect_no_assessment
      end
    end

    it "スタッフの画面を JSON で開くと 406（JSON では返さない）で、含まれない" do
      staff_paths.each do |path|
        get path, headers: { "Accept" => json }
        expect(response).to have_http_status(:not_acceptable)
        expect_no_assessment
      end
    end

    [ [ "Turbo Stream", :turbo_stream ], [ "JSON", :json ] ].each do |label, accept_name|
      it "確認・自己申告を #{label} で送っても、リダイレクトで返り、その先の画面にも含まれない" do
        post staff_operation_confirmation_path(santei), params: { version: 2 }, headers: { "Accept" => public_send(accept_name) }
        expect(response).to have_http_status(:see_other)
        expect_no_assessment
        follow_redirect!
        expect_no_assessment

        post staff_operation_self_declaration_path(year_end), params: { level: 3 }, headers: { "Accept" => public_send(accept_name) }
        expect(response).to have_http_status(:see_other)
        expect_no_assessment
        follow_redirect!
        expect_no_assessment
      end

      it "「教え終わった」を #{label} で送っても、リダイレクトで返り、その先の画面にも含まれない" do
        operate_as(yamamoto)

        post training_completion_path(training_for_kato), headers: { "Accept" => public_send(accept_name) }
        expect(response).to have_http_status(:see_other)
        expect_no_assessment
        follow_redirect!
        expect_no_assessment
      end
    end
  end

  describe "AC-4：スタッフが見立ての保存を呼ぶと、拒否され、値が変わらない" do
    # 付けていない人に付ける形は spec/requests/skills/assessments_spec.rb（AC-7）で確かめている。ここでは足りない形を確かめる
    def assessment_columns
      Skill.order(:id).pluck(:id, :admin_assessment, :admin_assessed_at, :admin_assessed_by_id)
    end

    before { operate_as(yamamoto) }

    {
      "ほかの人の見立てを変える（▼ → ▲）" => -> { { skill_of(kato, payroll).id => "can_train" } },
      "自分の見立てを外す（▲ → なし）" => -> { { skill_of(yamamoto, year_end).id => "" } },
      "自分のスキルに見立てを付ける" => -> { { skill_of(yamamoto, payroll).id => "backup_trainer" } }
    }.each do |label, assessments|
      [ [ "ふつうのフォーム", nil ], [ "Turbo Stream", :turbo_stream ], [ "JSON", :json ] ].each do |kind, accept_name|
        it "#{label}：#{kind}で送っても拒否され、見立て・付けた日時・付けた人が変わらない" do
          headers = accept_name ? { "Accept" => public_send(accept_name) } : {}

          expect { patch skills_assessment_path, params: { assessments: instance_exec(&assessments) }, headers: }
            .not_to(change { assessment_columns })
          expect(response).to redirect_to(staff_operations_path)
          expect_no_assessment
        end
      end
    end
  end
end
