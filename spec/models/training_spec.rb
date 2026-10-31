require "rails_helper"

RSpec.describe Training do
  describe "バリデーション" do
    it "作業・教える人・教わる人があれば保存できる" do
      expect(build(:training)).to be_valid
    end

    it "期限は空でも保存できる" do
      expect(build(:training, due_on: nil)).to be_valid
    end

    it "作業がないと保存できない" do
      expect(build(:training, operation: nil, trainer: create(:user), trainee: create(:user))).not_to be_valid
    end

    it "教える人がいないと保存できない" do
      expect(build(:training, trainer: nil)).not_to be_valid
    end

    it "教わる人がいないと保存できない" do
      expect(build(:training, trainee: nil)).not_to be_valid
    end

    it "教える人と教わる人が同じだと保存できない" do
      user = create(:user)
      training = build(:training, trainer: user, trainee: user)

      expect(training).not_to be_valid
      expect(training.errors).to be_added(:trainee, :same_as_trainer)
    end
  end

  describe "未完了の予定は、同じ作業・同じ教わる人で1件まで" do
    let(:training) { create(:training) }

    it "未完了の予定があると、2件目を作れない" do
      expect(build(:training, operation: training.operation, trainee: training.trainee)).not_to be_valid
    end

    it "確認済み（acknowledged）の予定も未完了として数える" do
      training.acknowledged!

      expect(build(:training, operation: training.operation, trainee: training.trainee)).not_to be_valid
    end

    it "完了した予定があっても、新しく作れる" do
      training.done!

      expect(build(:training, operation: training.operation, trainee: training.trainee)).to be_valid
    end

    it "別の作業なら作れる" do
      other = create(:operation)
      create(:skill, operation: other, user: training.trainee, level: 0)

      expect(build(:training, operation: other, trainee: training.trainee)).to be_valid
    end

    it "DB でも未完了の予定を2件作れない" do
      duplicate = build(:training, operation: training.operation, trainee: training.trainee)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "DB では完了した予定は何件あってもよい" do
      training.done!
      another = build(:training, operation: training.operation, trainee: training.trainee, status: :done)

      expect { another.save!(validate: false) }.not_to raise_error
    end
  end

  describe "status" do
    it "既定値は requested" do
      expect(described_class.new.status).to eq "requested"
    end

    it "数字が決まっている（部分ユニークインデックスの条件 status <> 2 と合わせる）" do
      expect(described_class.statuses).to eq("requested" => 0, "acknowledged" => 1, "done" => 2)
    end

    it "3つ以外の値だと保存できない" do
      expect(build(:training, status: "unknown")).not_to be_valid
    end
  end

  it "作業から研修予定をたどれる" do
    training = create(:training)

    expect(training.operation.trainings).to contain_exactly(training)
  end

  describe "作成時の教える人の条件" do
    let(:operation) { create(:operation) }

    def trainer_with(level:, admin_assessment: nil)
      create(:skill, operation:, level:, admin_assessment:).user
    end

    def build_training(trainer)
      build(:training, operation:, trainer:)
    end

    it "レベル4の人は教える人にできる（見立てなし・◇・▽）" do
      [ nil, :backup_trainer, :training_done ].each do |admin_assessment|
        expect(build_training(trainer_with(level: 4, admin_assessment:))).to be_valid
      end
    end

    it "レベル3で▲の人は教える人にできる" do
      expect(build_training(trainer_with(level: 3, admin_assessment: :can_train))).to be_valid
    end

    it "管理者はスキルがなくても、どの作業でも教える人にできる" do
      expect(build_training(create(:user, :admin))).to be_valid
    end

    it "条件を満たさない人は教える人にできない" do
      [
        { level: 4, admin_assessment: :needs_training },
        { level: 3 },
        { level: 3, admin_assessment: :needs_training },
        { level: 2 },
        { level: 1 },
        { level: 0 }
      ].each do |attributes|
        training = build_training(trainer_with(**attributes))

        expect(training).not_to be_valid, "#{attributes} で作れてしまう"
        expect(training.errors).to be_added(:trainer, :not_trainer_candidate)
      end
    end

    it "その作業のスキルがないスタッフは教える人にできない" do
      user = create(:skill, level: 4).user

      expect(build_training(user)).not_to be_valid
    end
  end

  describe "作成時の教わる人の条件" do
    let(:operation) { create(:operation) }

    def trainee_with(level:, admin_assessment: nil)
      create(:skill, operation:, level:, admin_assessment:).user
    end

    def build_training(trainee)
      build(:training, operation:, trainee:)
    end

    it "レベル0・1の人は教わる人にできる" do
      [ 0, 1 ].each do |level|
        expect(build_training(trainee_with(level:))).to be_valid
      end
    end

    it "▼の人は教わる人にできる（4▼も含む）" do
      [ 3, 4 ].each do |level|
        expect(build_training(trainee_with(level:, admin_assessment: :needs_training))).to be_valid
      end
    end

    it "▼のないレベル2〜4の人は教わる人にできない" do
      [
        { level: 2 },
        { level: 2, admin_assessment: :training_done },
        { level: 3 },
        { level: 3, admin_assessment: :can_train },
        { level: 4 },
        { level: 4, admin_assessment: :backup_trainer }
      ].each do |attributes|
        training = build_training(trainee_with(**attributes))

        expect(training).not_to be_valid, "#{attributes} で作れてしまう"
        expect(training.errors).to be_added(:trainee, :not_trainee_candidate)
      end
    end

    it "管理者は教わる人にできない" do
      expect(build_training(create(:user, :admin))).not_to be_valid
    end
  end

  describe "作成後にレベルや見立てが変わったとき" do
    let(:training) { create(:training) }

    before do
      # 教わる人が自己申告で3に上げ、教える人が申告を取り消して3に下がった
      Skill.find_by!(operation: training.operation, user: training.trainee).update!(level: 3)
      Skill.find_by!(operation: training.operation, user: training.trainer).update!(level: 3)
    end

    it "期限を変えられる" do
      expect(training.update(due_on: Date.new(2026, 11, 30))).to be true
    end

    it "確認済みにできる" do
      expect(training.update(status: :acknowledged)).to be true
    end

    it "完了にできる" do
      expect(training.update(status: :done, done_on: Date.new(2026, 11, 3))).to be true
    end
  end
end
