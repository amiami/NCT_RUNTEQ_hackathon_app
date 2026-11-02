require "rails_helper"

RSpec.describe TrainingBoard do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }

  # 名前で結果を見やすくするため、作業ごとにレベルと見立てを指定してスキルを作る
  def skill_in(operation, level, assessment = nil, name:, sort_order: nil)
    user = User.find_by(name:) || create(:user, name:, sort_order: sort_order || User.maximum(:sort_order).to_i + 1)
    create(:skill, operation:, user:, level:, admin_assessment: assessment)
  end

  # 教える人を管理者にして、ほかの人のスキル（できる人の数など）を増やさずに予定を作る
  def unfinished_training(operation, trainee_name)
    create(:training, operation:, trainer: admin, trainee: User.find_by!(name: trainee_name))
  end

  def card_for(operation)
    described_class.cards.find { |card| card.operation == operation }
  end

  def names(users)
    users.map(&:name)
  end

  describe "研修画面に出す作業（AC-1）" do
    it "レベル0・1の人がいる作業は出る" do
      level0 = create(:operation)
      skill_in(level0, 0, name: "山本")
      level1 = create(:operation)
      skill_in(level1, 1, name: "中村")

      expect(described_class.cards.map(&:operation)).to contain_exactly(level0, level1)
    end

    it "▼の人だけがいる作業も出る（4▼も含む）" do
      level3 = create(:operation)
      skill_in(level3, 3, :needs_training, name: "山本")
      level4 = create(:operation)
      skill_in(level4, 4, :needs_training, name: "中村")

      expect(described_class.cards.map(&:operation)).to contain_exactly(level3, level4)
    end

    it "レベル0・1の人も▼の人もいない作業は出ない" do
      operation = create(:operation)
      skill_in(operation, 2, name: "山本")
      skill_in(operation, 3, :can_train, name: "中村")
      skill_in(operation, 3, :training_done, name: "小林")
      skill_in(operation, 4, :backup_trainer, name: "加藤")

      expect(described_class.cards).to be_empty
    end
  end

  describe "教える人の候補（AC-2）" do
    it "レベル4（◇・▼以外）→ 3▲ → 4◇ の順に並び、管理者はいつも最後" do
      operation = create(:operation)
      skill_in(operation, 4, :backup_trainer, name: "中村")
      skill_in(operation, 3, :can_train, name: "小林")
      skill_in(operation, 4, name: "山本")
      skill_in(operation, 4, :needs_training, name: "加藤")
      skill_in(operation, 0, name: "吉田")

      expect(names(card_for(operation).trainers)).to eq [ "山本", "小林", "中村", "管理者" ]
    end

    it "教える人の候補のスキルがいなくても、管理者は入る" do
      operation = create(:operation)
      skill_in(operation, 0, name: "吉田")

      expect(names(card_for(operation).trainers)).to eq [ "管理者" ]
    end

    it "別の作業のスキルは候補に入れない" do
      operation = create(:operation)
      skill_in(operation, 0, name: "吉田")
      skill_in(create(:operation), 4, name: "山本")

      expect(names(card_for(operation).trainers)).to eq [ "管理者" ]
    end
  end

  describe "教わる人の候補（AC-3）" do
    let(:operation) { create(:operation) }

    before do
      skill_in(operation, 0, name: "0の人")
      skill_in(operation, 1, name: "1の人")
      skill_in(operation, 2, name: "2の人")
      skill_in(operation, 3, name: "3の人")
      skill_in(operation, 3, :needs_training, name: "3▼の人")
      skill_in(operation, 4, name: "4の人")
      skill_in(operation, 4, :needs_training, name: "4▼の人")
    end

    it "レベル0・1の人と▼の人（4▼も含む）が入り、▼のないレベル2〜4の人は入らない" do
      expect(names(card_for(operation).trainee_skills.map(&:user))).to eq [ "0の人", "1の人", "3▼の人", "4▼の人" ]
    end

    it "その作業で未完了の予定がある人は入らない" do
      unfinished_training(operation, "1の人")
      unfinished_training(operation, "4▼の人")

      expect(names(card_for(operation).trainee_skills.map(&:user))).to eq [ "0の人", "3▼の人" ]
    end

    it "完了した予定しかない人は入る" do
      training = unfinished_training(operation, "0の人")
      training.update!(status: :done, done_on: Date.new(2026, 10, 1))

      expect(names(card_for(operation).trainee_skills.map(&:user))).to include("0の人")
    end

    it "別の作業で未完了の予定があっても入る" do
      other = create(:operation)
      skill_in(other, 0, name: "0の人")
      unfinished_training(other, "0の人")

      expect(names(card_for(operation).trainee_skills.map(&:user))).to include("0の人")
    end
  end

  describe "カードの状態（AC-4）" do
    let(:operation) { create(:operation) }

    before do
      skill_in(operation, 0, name: "山本")
      skill_in(operation, 3, :needs_training, name: "中村")
    end

    it "対象の人に未完了の予定が1件もなければ「未指示」" do
      expect(card_for(operation).status).to eq :unassigned
    end

    it "対象の人の一部に未完了の予定があれば「一部 指示済み」" do
      unfinished_training(operation, "中村")

      expect(card_for(operation).status).to eq :partially_assigned
    end

    it "対象の人の全員に未完了の予定があれば「指示済み」" do
      unfinished_training(operation, "山本")
      unfinished_training(operation, "中村")

      expect(card_for(operation).status).to eq :assigned
    end

    it "完了した予定は、指示済みに数えない" do
      unfinished_training(operation, "山本").update!(status: :done, done_on: Date.new(2026, 10, 1))

      expect(card_for(operation).status).to eq :unassigned
    end
  end

  describe "カードの並び順（AC-5）" do
    let(:category) { create(:category, sort_order: 1) }

    # できる人（レベル4）の人数と、全員に予定を入れるかを指定して作業を作る
    def operation_with(name, capable:, assigned: false, category: self.category, sort_order: nil)
      operation = create(:operation, name:, category:, sort_order: sort_order || Operation.maximum(:sort_order).to_i + 1)
      capable.times { |i| skill_in(operation, 4, name: "#{name}のできる人#{i}") }
      skill_in(operation, 0, name: "#{name}の未研修")
      unfinished_training(operation, "#{name}の未研修") if assigned
      operation
    end

    it "「指示が必要」（未指示・一部 指示済み）の作業が、「指示済み」より上に並ぶ" do
      assigned = operation_with("指示済み", capable: 0, assigned: true)
      unassigned = operation_with("未指示", capable: 3)

      expect(described_class.cards.map(&:operation)).to eq [ unassigned, assigned ]
    end

    it "「指示が必要」の中では、できる人が少ない作業が先に並ぶ" do
      two = operation_with("2人", capable: 2)
      zero = operation_with("0人", capable: 0)
      one = operation_with("1人", capable: 1)

      expect(described_class.cards.map(&:operation)).to eq [ zero, one, two ]
    end

    it "できる人の数が同じなら、分類の並び順 → 作業の並び順" do
      later_category = create(:category, sort_order: 2)
      in_later_category = operation_with("後の分類", capable: 1, category: later_category, sort_order: 1)
      second = operation_with("2番目", capable: 1, sort_order: 2)
      first = operation_with("1番目", capable: 1, sort_order: 1)

      expect(described_class.cards.map(&:operation)).to eq [ first, second, in_later_category ]
    end

    it "カードのできる人の数は、その作業のレベル4の人数" do
      operation = operation_with("2人", capable: 2)

      expect(card_for(operation).capable_count).to eq 2
    end
  end

  it "作業の数が増えても、DB への問い合わせの回数は変わらない" do
    count_queries = lambda do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.cards.each { |card| [ card.trainers, card.trainee_skills.map(&:user), card.operation.category ] }
      end
      queries.size
    end

    operation = create(:operation)
    skill_in(operation, 0, name: "山本")
    skill_in(operation, 4, name: "中村")
    one_operation = count_queries.call

    2.times do |i|
      other = create(:operation)
      skill_in(other, 0, name: "未研修#{i}")
      skill_in(other, 4, name: "できる人#{i}")
      unfinished_training(other, "未研修#{i}")
    end

    expect(count_queries.call).to eq one_operation
  end
end
