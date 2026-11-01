require "rails_helper"

RSpec.describe TrainingPlan do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:payroll) { create(:operation, name: "給与計算") }
  let(:year_end) { create(:operation, name: "年末調整") }

  # 名前で読みやすくするため、作業ごとにレベルと見立てを指定してスキルを作る
  def skill_in(operation, level, assessment = nil, name:)
    user = User.find_by(name:) || create(:user, name:)
    create(:skill, operation:, user:, level:, admin_assessment: assessment)
    user
  end

  def addition(operation, trainer, trainee, due_on: nil)
    { operation_id: operation.id, trainer_id: trainer.id, trainee_id: trainee.id, due_on: }
  end

  def save_plan(additions: [], cancellations: [], due_dates: [])
    plan = described_class.new(additions:, cancellations:, due_dates:)
    [ plan.save, plan ]
  end

  # 何も変わっていないことを確かめるための、研修予定の中身の写し
  def snapshot
    Training.order(:id).pluck(:id, :operation_id, :trainer_id, :trainee_id, :status, :due_on)
  end

  describe "AC-1: まとめて保存" do
    it "複数の作業・複数の人の追加・取り消し・期限の変更を、1回で反映できる" do
      yamamoto = skill_in(payroll, 4, name: "山本")
      yoshida = skill_in(payroll, 1, name: "吉田")
      kato = skill_in(year_end, 0, name: "加藤")
      skill_in(year_end, 4, name: "山本")
      kobayashi = skill_in(year_end, 0, name: "小林")
      old = create(:training, operation: year_end, trainer: admin, trainee: kobayashi)

      saved, = save_plan(
        additions: [ addition(payroll, yamamoto, yoshida), addition(year_end, yamamoto, kato) ],
        cancellations: [ old.id ],
        due_dates: [ { operation_id: year_end.id, due_on: "2026-11-30" } ]
      )

      expect(saved).to be(true)
      expect(Training.exists?(old.id)).to be(false)
      expect(Training.unfinished.pluck(:operation_id, :trainee_id, :due_on)).to contain_exactly(
        [ payroll.id, yoshida.id, nil ], [ year_end.id, kato.id, Date.new(2026, 11, 30) ]
      )
    end

    it "何も送らなければ、何も変えずに成功する" do
      expect(save_plan).to match([ true, anything ])
    end
  end

  describe "AC-2: 1人につき1件" do
    it "3人を対象にすると、3件の予定ができる" do
      yamamoto = skill_in(payroll, 4, name: "山本")
      trainees = [ skill_in(payroll, 0, name: "加藤"), skill_in(payroll, 1, name: "吉田"),
                   skill_in(payroll, 3, :needs_training, name: "中村") ]

      saved, = save_plan(additions: trainees.map { |trainee| addition(payroll, yamamoto, trainee, due_on: "2026-12-10") })

      expect(saved).to be(true)
      expect(Training.where(operation: payroll, trainer: yamamoto).pluck(:trainee_id, :due_on))
        .to match_array(trainees.map { |trainee| [ trainee.id, Date.new(2026, 12, 10) ] })
    end
  end

  describe "AC-3: 教える人が管理者の予定" do
    it "管理者が教える人なら acknowledged、スタッフなら requested で作られる" do
      yamamoto = skill_in(payroll, 4, name: "山本")
      yoshida = skill_in(payroll, 1, name: "吉田")
      kato = skill_in(payroll, 0, name: "加藤")

      save_plan(additions: [ addition(payroll, admin, yoshida), addition(payroll, yamamoto, kato) ])

      expect(Training.find_by!(trainee: yoshida)).to be_acknowledged
      expect(Training.find_by!(trainee: kato)).to be_requested
    end
  end

  describe "AC-4: 期限の変更" do
    it "その作業の未完了の予定すべてが同じ期限になり、完了した予定とほかの作業の予定は変わらない" do
      yoshida = skill_in(payroll, 1, name: "吉田")
      kato = skill_in(payroll, 0, name: "加藤")
      unfinished = [ create(:training, operation: payroll, trainer: admin, trainee: yoshida, due_on: "2026-11-10"),
                     create(:training, operation: payroll, trainer: admin, trainee: kato) ]
      done = create(:training, operation: payroll, trainer: admin, trainee: skill_in(payroll, 0, name: "小林"))
      done.update!(status: :done, done_on: "2026-10-01", due_on: "2026-09-30")
      other = create(:training, operation: year_end, trainer: admin, trainee: skill_in(year_end, 0, name: "吉田"),
                                due_on: "2026-11-10")

      saved, = save_plan(due_dates: [ { operation_id: payroll.id, due_on: "2026-12-01" } ])

      expect(saved).to be(true)
      expect(unfinished.map { |training| training.reload.due_on }).to all(eq(Date.new(2026, 12, 1)))
      expect(done.reload.due_on).to eq(Date.new(2026, 9, 30))
      expect(other.reload.due_on).to eq(Date.new(2026, 11, 10))
    end

    it "期限を空にすると、未完了の予定の期限が消える" do
      training = create(:training, operation: payroll, trainer: admin, trainee: skill_in(payroll, 1, name: "吉田"),
                                   due_on: "2026-11-10")

      save_plan(due_dates: [ { operation_id: payroll.id, due_on: "" } ])

      expect(training.reload.due_on).to be_nil
    end

    it "予定がない作業の期限は、どこにも保存されない" do
      skill_in(payroll, 1, name: "吉田")

      saved, = save_plan(due_dates: [ { operation_id: payroll.id, due_on: "2026-12-01" } ])

      expect(saved).to be(true)
      expect(Training.count).to eq(0)
    end

    it "その回で追加した予定にも、変えた期限がそろう" do
      yamamoto = skill_in(payroll, 4, name: "山本")
      yoshida = skill_in(payroll, 1, name: "吉田")
      kato = skill_in(payroll, 0, name: "加藤")
      create(:training, operation: payroll, trainer: admin, trainee: kato, due_on: "2026-11-10")

      save_plan(additions: [ addition(payroll, yamamoto, yoshida, due_on: "2026-11-10") ],
                due_dates: [ { operation_id: payroll.id, due_on: "2026-12-01" } ])

      expect(Training.where(operation: payroll).pluck(:due_on)).to all(eq(Date.new(2026, 12, 1)))
    end

    it "日付として読めない期限は保存できず、何も変わらない" do
      create(:training, operation: payroll, trainer: admin, trainee: skill_in(payroll, 1, name: "吉田"))

      expect { save_plan(due_dates: [ { operation_id: payroll.id, due_on: "2026-13-45" } ]) }
        .not_to(change { snapshot })
      expect(save_plan(due_dates: [ { operation_id: payroll.id, due_on: "2026-13-45" } ]).last.errors)
        .to include("期限の日付が正しくありません")
    end
  end

  describe "AC-5: 1件でも保存できないと、何も保存しない" do
    let!(:yamamoto) { skill_in(payroll, 4, name: "山本") }
    let!(:yoshida) { skill_in(payroll, 1, name: "吉田") }
    let!(:old) { create(:training, operation: payroll, trainer: admin, trainee: skill_in(payroll, 0, name: "加藤")) }

    def mixed_with(bad_addition)
      save_plan(
        additions: [ addition(payroll, yamamoto, yoshida), bad_addition ],
        cancellations: [ old.id ],
        due_dates: [ { operation_id: payroll.id, due_on: "2026-12-01" } ]
      )
    end

    it "教える人が条件を満たさない予定が混じると、ほかの追加・取り消し・期限の変更も反映しない" do
      not_trainer = skill_in(year_end, 3, name: "中村")
      trainee = skill_in(year_end, 0, name: "小林")

      expect { mixed_with(addition(year_end, not_trainer, trainee)) }.not_to(change { snapshot })
    end

    it "教わる人が条件を満たさない予定が混じると、何も反映しない" do
      skill_in(year_end, 4, name: "山本")
      not_trainee = skill_in(year_end, 2, name: "小林")

      expect { mixed_with(addition(year_end, yamamoto, not_trainee)) }.not_to(change { snapshot })
    end

    it "保存できなかった理由を、作業と人の名前つきで返す" do
      skill_in(year_end, 4, name: "山本")
      not_trainee = skill_in(year_end, 2, name: "小林")

      saved, plan = mixed_with(addition(year_end, yamamoto, not_trainee))

      expect(saved).to be(false)
      expect(plan.errors).to contain_exactly("年末調整（小林）：教わる人はこの作業で教わる人の条件を満たしていません")
    end

    it "存在しない予定を取り消そうとすると、何も反映しない" do
      expect { save_plan(additions: [ addition(payroll, yamamoto, yoshida) ], cancellations: [ 0 ]) }
        .not_to(change { snapshot })
      expect(save_plan(cancellations: [ 0 ]).last.errors).to include("取り消す研修予定が見つかりません")
    end
  end

  describe "AC-6: 同じ内容を2回送ったとき" do
    let!(:yamamoto) { skill_in(payroll, 4, name: "山本") }
    let!(:yoshida) { skill_in(payroll, 1, name: "吉田") }

    it "2回目は保存できず、同じ人の未完了の予定は1件のまま" do
      first, = save_plan(additions: [ addition(payroll, yamamoto, yoshida) ])
      second, plan = save_plan(additions: [ addition(payroll, yamamoto, yoshida) ])

      expect([ first, second ]).to eq([ true, false ])
      expect(Training.unfinished.where(operation: payroll, trainee: yoshida).count).to eq(1)
      expect(plan.errors).to contain_exactly("給与計算（吉田）：教わる人にはこの作業で完了していない研修予定がすでにあります")
    end

    it "ほぼ同時に届いて DB のインデックスで弾かれたときも、例外で止まらず保存できなかったとして返す" do
      allow(Training).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      saved, plan = save_plan(additions: [ addition(payroll, yamamoto, yoshida) ])

      expect(saved).to be(false)
      expect(plan.errors).to contain_exactly("同じ人の未完了の研修予定がすでにあります。画面を開き直してください")
    end
  end

  describe "AC-7: 完了した予定" do
    it "取り消せず、何も反映しない" do
      done = create(:training, operation: payroll, trainer: admin, trainee: skill_in(payroll, 1, name: "吉田"))
      done.update!(status: :done, done_on: "2026-10-01")

      expect { save_plan(cancellations: [ done.id ]) }.not_to(change { snapshot })
      expect(save_plan(cancellations: [ done.id ]).last.errors).to contain_exactly("給与計算（吉田）：完了した研修予定は削除できません")
    end
  end

  it "同じ人の予定を取り消して、別の教える人で頼み直すことが1回でできる" do
    yamamoto = skill_in(payroll, 4, name: "山本")
    yoshida = skill_in(payroll, 1, name: "吉田")
    old = create(:training, operation: payroll, trainer: admin, trainee: yoshida)

    saved, = save_plan(additions: [ addition(payroll, yamamoto, yoshida) ], cancellations: [ old.id ])

    expect(saved).to be(true)
    expect(Training.unfinished.where(operation: payroll, trainee: yoshida).pluck(:trainer_id)).to eq([ yamamoto.id ])
  end
end
