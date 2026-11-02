require "rails_helper"

RSpec.describe TrainingCompletion do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let(:yoshida) { create(:user, name: "吉田", sort_order: 2) }
  let(:payroll) { create(:operation, name: "給与計算") }
  let(:now) { Time.zone.local(2026, 11, 2, 10, 30) }

  before do
    travel_to(now)
    create(:manual, operation: payroll, version: 3)
    create(:skill, operation: payroll, user: yamamoto, level: 4)
  end

  # 吉田が教わる人の予定。教わる人のスキルは、作成時の条件を満たす状態で作ってから、テストごとの状態に変える
  def training_for(level: 1, assessment: nil, confirmed_version: nil, trainer: yamamoto)
    skill = create(:skill, operation: payroll, user: yoshida, level: [ level, 1 ].min,
                           admin_assessment: (assessment == :needs_training ? :needs_training : nil))
    training = create(:training, operation: payroll, trainer:, trainee: yoshida)
    skill.update!(level:, admin_assessment: assessment, confirmed_version:)
    training
  end

  def trainee_skill
    Skill.find_by!(operation: payroll, user: yoshida)
  end

  def complete(training, by:)
    completion = described_class.new(training:, by:)
    [ completion.save, completion ]
  end

  # 何も変わっていないことを確かめるための、予定・スキル・記録の写し
  def snapshot
    [
      Training.order(:id).pluck(:id, :status, :done_on),
      Skill.order(:id).pluck(:id, :level, :confirmed_version, :admin_assessment, :admin_assessed_at, :admin_assessed_by_id),
      SkillLevelChange.count
    ]
  end

  describe "AC-1: 予定を完了にする" do
    it "予定が done になり、done_on が今日になる。未完了の予定から外れる" do
      training = training_for

      saved, = complete(training, by: yamamoto)

      expect(saved).to be(true)
      expect(training.reload).to be_done
      expect(training.done_on).to eq(Date.new(2026, 11, 2))
      expect(Training.unfinished).not_to include(training)
    end
  end

  describe "AC-2: 教わる人のレベル" do
    [ 0, 1 ].each do |level|
      it "レベル#{level}の人はレベル2になり、trained の記録が1件増える" do
        training = training_for(level:)

        expect { complete(training, by: yamamoto) }.to change(SkillLevelChange, :count).by(1)

        expect(trainee_skill.level).to eq 2
        expect(SkillLevelChange.last).to have_attributes(
          skill: trainee_skill, changed_by: yamamoto, from_level: level, to_level: 2, reason: "trained"
        )
      end
    end

    [ [ 2, nil ], [ 3, nil ], [ 3, :needs_training ], [ 4, :needs_training ] ].each do |level, assessment|
      it "レベル#{level}#{'▼' if assessment}の人はレベルが変わらず、記録も増えない" do
        training = training_for(level:, assessment:)

        expect { complete(training, by: yamamoto) }.not_to change(SkillLevelChange, :count)

        expect(training.reload).to be_done
        expect(trainee_skill.level).to eq level
      end
    end
  end

  describe "AC-3: マニュアルを確認した版" do
    [ nil, 1 ].each do |confirmed_version|
      it "確認した版が#{confirmed_version.inspect}の人も、マニュアルの今の版になる" do
        training = training_for(confirmed_version:)

        complete(training, by: yamamoto)

        expect(trainee_skill.confirmed_version).to eq 3
        expect(trainee_skill.unread?).to be(false)
      end
    end
  end

  describe "AC-4: 管理者の見立て" do
    it "▼の人は▽になり、付けた日時と付けた人が、今の日時と押した人になる" do
      training = training_for(level: 3, assessment: :needs_training)
      trainee_skill.update!(admin_assessed_at: Time.zone.local(2026, 10, 20), admin_assessed_by: admin)

      complete(training, by: yamamoto)

      expect(trainee_skill).to have_attributes(
        admin_assessment: "training_done", admin_assessed_at: now, admin_assessed_by: yamamoto
      )
    end

    [ nil, :can_train, :training_done, :backup_trainer ].each do |assessment|
      it "見立てが#{assessment.inspect}の人は、見立ても付けた日時・付けた人も変わらない" do
        training = training_for(level: 1, assessment:)
        assessed_at = Time.zone.local(2026, 10, 20)
        trainee_skill.update!(admin_assessed_at: assessed_at, admin_assessed_by: admin) if assessment

        complete(training, by: yamamoto)

        expect(trainee_skill).to have_attributes(
          admin_assessment: assessment&.to_s, admin_assessed_at: (assessed_at if assessment),
          admin_assessed_by: (admin if assessment)
        )
      end
    end
  end

  describe "AC-5: 完了した予定" do
    it "もう一度「教え終わった」にできず、何も変わらない" do
      training = training_for
      complete(training, by: yamamoto)

      saved, completion = nil
      expect { saved, completion = complete(training, by: yamamoto) }.not_to(change { snapshot })
      expect(saved).to be(false)
      expect(completion.errors).to contain_exactly("この研修予定はすでに完了しています")
    end

    it "読み込んだあとに別の操作で完了していても、もう一度は完了にしない" do
      training = training_for
      stale = Training.find(training.id) # 画面を開いたときに読み込んだ予定（まだ未完了）
      complete(training, by: yamamoto)

      expect { complete(stale, by: yamamoto) }.not_to(change { snapshot })
    end
  end

  describe "AC-6: 教える人以外は押せない" do
    let(:kato) { create(:user, name: "加藤", sort_order: 3) }

    it "ほかのスタッフ・教わる人本人・スタッフが担当の予定に管理者が押すと、何も変わらない" do
      training = training_for

      [ kato, yoshida, admin ].each do |someone|
        saved, completion = nil
        expect { saved, completion = complete(training, by: someone) }.not_to(change { snapshot })
        expect(saved).to be(false)
        expect(completion.errors).to contain_exactly("この研修予定の教える人だけが「教え終わった」にできます")
      end
    end

    it "押した人がいない（nil）ときも、何も変わらない" do
      training = training_for

      expect { complete(training, by: nil) }.not_to(change { snapshot })
    end
  end

  describe "AC-7: 管理者が担当の予定" do
    it "管理者が押せて、記録の changed_by も管理者になる" do
      training = training_for(level: 0, trainer: admin)

      saved, = complete(training, by: admin)

      expect(saved).to be(true)
      expect(training.reload).to be_done
      expect(SkillLevelChange.last).to have_attributes(changed_by: admin, from_level: 0, to_level: 2)
    end
  end

  it "途中で保存できなかったときは、予定もスキルも記録も元のまま" do
    training = training_for(level: 1, assessment: :needs_training)
    allow(SkillLevelChange).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(SkillLevelChange.new))

    saved = nil
    expect { saved, = complete(training, by: yamamoto) }.not_to(change { snapshot })
    expect(saved).to be(false)
  end
end
