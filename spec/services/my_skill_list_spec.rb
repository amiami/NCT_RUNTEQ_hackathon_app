require "rails_helper"

RSpec.describe MySkillList do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:kobayashi) { create(:user, name: "小林", sort_order: 1) }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 2) }

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

  describe "AC-1: レベル0〜4ごとの件数" do
    it "自分のスキルをレベルごとに数え、0件のレベルも0として出す。ほかの人のスキルは数えない" do
      category = create(:category)
      [ 4, 4, 2, 0 ].each_with_index do |level, index|
        create(:skill, operation: operation_in(category, "作業#{index}", sort_order: index), user: kobayashi, level:)
      end
      create(:skill, operation: Operation.first, user: yamamoto, level: 1)

      list = described_class.for(kobayashi)

      expect(list.level_counts).to eq(0 => 1, 1 => 0, 2 => 1, 3 => 0, 4 => 2)
      expect(list.level_counts.values.sum).to eq kobayashi.skills.count
    end
  end

  describe "AC-2: 分類ごとの並び" do
    it "分類の並び順 → 作業の並び順で、作業とレベルが入る" do
      later = create(:category, name: "勤怠・給与", sort_order: 2)
      first = create(:category, name: "入退社", sort_order: 1)
      create(:skill, operation: operation_in(later, "給与計算", sort_order: 1), user: kobayashi, level: 2)
      create(:skill, operation: operation_in(first, "退職手続き", sort_order: 2), user: kobayashi, level: 4)
      create(:skill, operation: operation_in(first, "入社手続き", sort_order: 1), user: kobayashi, level: 3)

      categories = described_class.for(kobayashi).categories

      expect(categories.map { |category, _rows| category.name }).to eq %w[入退社 勤怠・給与]
      expect(categories.first.last.map { |row| [ row.operation.name, row.level ] })
        .to eq [ [ "入社手続き", 3 ], [ "退職手続き", 4 ] ]
    end
  end

  describe "AC-3: 研修済み・再確認" do
    let(:category) { create(:category) }

    def row_for(name)
      described_class.for(kobayashi).categories.flat_map(&:last).find { |row| row.operation.name == name }
    end

    it "完了した研修があれば研修済み（レベル3以上でも）。なければ研修済みではない" do
      trained = operation_in(category, "給与計算", sort_order: 1)
      create(:skill, operation: trained, user: kobayashi, level: 3)
      done_training(trained, kobayashi)
      create(:skill, operation: operation_in(category, "入社手続き", sort_order: 2), user: kobayashi, level: 4)

      expect(row_for("給与計算")).to be_trained
      expect(row_for("入社手続き")).not_to be_trained
    end

    it "再確認は、確認した版が古いときだけ。一度も確認していない・今の版を確認した作業には出ない" do
      create(:skill, operation: operation_in(category, "古い版", sort_order: 1, version: 2), user: kobayashi, level: 1,
                     confirmed_version: 1)
      create(:skill, operation: operation_in(category, "今の版", sort_order: 2, version: 2), user: kobayashi, level: 1,
                     confirmed_version: 2)
      create(:skill, operation: operation_in(category, "未確認", sort_order: 3, version: 2), user: kobayashi, level: 0)

      expect(row_for("古い版")).to be_reconfirm
      expect(row_for("今の版")).not_to be_reconfirm
      expect(row_for("未確認")).not_to be_reconfirm
    end

    it "まとめて読んだ研修済みの判定は、Skill#training_status を1件ずつ読んだときと同じ" do
      operations = (1..3).map { |i| operation_in(category, "作業#{i}", sort_order: i) }
      create(:skill, operation: operations[0], user: kobayashi, level: 2)
      create(:skill, operation: operations[1], user: kobayashi, level: 3)
      create(:skill, operation: operations[2], user: kobayashi, level: 1)
      done_training(operations[0], kobayashi)

      rows = described_class.for(kobayashi).categories.flat_map(&:last)

      rows.each do |row|
        expect(row.trained?).to eq(Skill.find(row.skill.id).training_status == :done)
      end
    end
  end
end
