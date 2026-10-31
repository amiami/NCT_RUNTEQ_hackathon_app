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
      expect(build(:training, operation: nil)).not_to be_valid
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
      expect(build(:training, trainee: training.trainee)).to be_valid
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
end
