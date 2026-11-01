require "rails_helper"

RSpec.describe "サンプルデータ" do # rubocop:disable RSpec/DescribeClass -- モデル単体ではなく seeds の受入条件
  def seed
    load Rails.root.join("db/seeds.rb")
  end

  it "仕様の人数・作業数・全員分のスキルと履歴を用意する" do
    seed

    expect(User.where(admin: true).pluck(:name)).to eq([ "管理者" ])
    expect(User.skill_holders.order(:sort_order).pluck(:name)).to eq(
      [ "山本 直子", "中村 健太", "小林 由美", "加藤 翔", "吉田 あかり" ]
    )
    expect([ Category.count, Operation.count, Manual.count, Skill.count ]).to eq([ 4, 13, 13, 65 ])
    expect(Skill.where(user: User.where(admin: true))).to be_empty
    expect(ManualRevision.count).to eq(3)
    expect(Training.done.count).to eq(7)
    expect(Training.where.not(status: :done)).to be_empty
    expect(SkillLevelChange.count).to eq(0)
  end

  it "マニュアルの種類・本文・版と時期の目安をそろえる" do
    seed
    external_names = [ "社会保険の資格取得・喪失", "算定基礎届", "労働保険の年度更新", "年末調整" ]
    Manual.includes(:operation).find_each do |manual|
      name = manual.operation.name
      expect(manual.kind).to eq(external_names.include?(name) ? "external" : "internal")
      expect(manual.external? ? manual.url : manual.body).to eq(manual.external? ? "[#{name}のURL]" : "（サンプル）")
      expect(manual.version).to eq([ "有給休暇の管理", "社会保険の資格取得・喪失", "年末調整" ].include?(name) ? 2 : 1)
    end
    notes = Operation.where.not(season_note: nil).pluck(:name, :season_note).to_h
    expect(notes).to eq(
      "算定基礎届" => "年1回・夏（提出期限は案内ページで確認）", "労働保険の年度更新" => "年1回・初夏",
      "年末調整" => "毎年11月中に準備", "健康診断の手配" => "年1回"
    )
  end

  it "給与計算のデモ用研修を頼めて、年度更新は▲を付けた山本が教えられる" do
    seed
    yamamoto = User.find_by!(name: "山本 直子")
    yoshida = User.find_by!(name: "吉田 あかり")
    payroll = Operation.find_by!(name: "給与計算")
    expect(Training.new(operation: payroll, trainer: yamamoto, trainee: yoshida)).to be_valid
    operation = Operation.find_by!(name: "労働保険の年度更新")
    training = Training.new(operation:, trainer: yamamoto, trainee: yoshida)
    expect(training).not_to be_valid
    Skill.find_by!(user: yamamoto, operation:).update!(admin_assessment: :can_train)
    expect(training).to be_valid
  end

  it "全13作業のレベルとできる人数を表どおりにする" do
    seed
    expected = {
      "入社手続き" => [ 4, 4, 4, 0, 0 ], "雇用契約書の作成" => [ 4, 4, 4, 1, 0 ],
      "退職手続き" => [ 4, 3, 4, 0, 0 ], "勤怠の締め" => [ 4, 4, 3, 3, 0 ],
      "給与計算" => [ 4, 3, 2, 2, 1 ], "有給休暇の管理" => [ 4, 4, 4, 0, 0 ],
      "社会保険の資格取得・喪失" => [ 4, 4, 4, 1, 0 ], "算定基礎届" => [ 4, 3, 3, 0, 0 ],
      "労働保険の年度更新" => [ 3, 2, 3, 3, 0 ], "年末調整" => [ 4, 3, 2, 2, 2 ],
      "採用面接の日程調整" => [ 4, 4, 4, 0, 0 ], "健康診断の手配" => [ 4, 4, 4, 1, 0 ],
      "就業規則の管理" => [ 4, 3, 4, 0, 0 ]
    }
    expected.each do |name, levels|
      operation = Operation.find_by!(name:)
      expect(operation.skills.joins(:user).order("users.sort_order").pluck(:level)).to eq(levels)
      expect(operation.capable_count).to eq(levels.count(4))
    end
  end

  it "改定日と確認した版を再現する" do
    seed
    revisions = ManualRevision.includes(manual: :operation).map do |revision|
      [ revision.manual.operation.name, revision.version, revision.created_at.to_date.iso8601 ]
    end
    expect(revisions).to contain_exactly(
      [ "有給休暇の管理", 2, "2026-09-20" ],
      [ "社会保険の資格取得・喪失", 2, "2026-10-01" ], [ "年末調整", 2, "2026-10-15" ]
    )
    unread = Skill.includes(:user, operation: :manual).select(&:unread?).map do |skill|
      [ skill.operation.name, skill.user.name ]
    end
    expect(unread).to contain_exactly(
      [ "有給休暇の管理", "小林 由美" ],
      *[ "中村 健太", "小林 由美", "加藤 翔" ].map { |name| [ "社会保険の資格取得・喪失", name ] },
      *[ "中村 健太", "小林 由美", "加藤 翔", "吉田 あかり" ].map { |name| [ "年末調整", name ] }
    )
  end

  it "未着手は未確認、未読以外は現在の版を確認済みにする" do
    seed
    Skill.includes(operation: :manual).find_each do |skill|
      expected_version = if skill.level.zero?
        nil
      elsif skill.unread?
        1
      else
        skill.operation.manual.version
      end
      expect(skill.confirmed_version).to eq(expected_version)
    end
  end

  it "見立てと付けた人を再現する" do
    seed
    assessments = Skill.where.not(admin_assessment: nil).includes(:user, :operation, :admin_assessed_by).map do |skill|
      expect(skill.admin_assessed_at).to be_present
      [ skill.operation.name, skill.user.name, skill.admin_assessment, skill.admin_assessed_by.name ]
    end
    expect(assessments).to contain_exactly(
      [ "勤怠の締め", "小林 由美", "can_train", "管理者" ],
      [ "勤怠の締め", "中村 健太", "backup_trainer", "管理者" ],
      [ "年末調整", "中村 健太", "needs_training", "管理者" ],
      [ "算定基礎届", "中村 健太", "training_done", "山本 直子" ]
    )
  end

  it "完了した研修の相手と日付を再現する" do
    seed
    trainings = Training.includes(:operation, :trainer, :trainee).map do |training|
      expect(training.due_on).to be_nil
      [ training.operation.name, training.trainer.name, training.trainee.name, training.done_on.iso8601 ]
    end
    expect(trainings).to contain_exactly(
      [ "給与計算", "山本 直子", "小林 由美", "2026-06-25" ],
      [ "給与計算", "山本 直子", "加藤 翔", "2026-07-24" ],
      [ "労働保険の年度更新", "管理者", "中村 健太", "2026-06-10" ],
      [ "算定基礎届", "山本 直子", "中村 健太", "2026-06-20" ],
      *[ "小林 由美", "加藤 翔", "吉田 あかり" ].map { |name| [ "年末調整", "山本 直子", name, "2026-10-05" ] }
    )
  end

  it "研修画面の候補：勤怠の締めの教える人は 山本 → 小林▲ → 中村◇ → 管理者、年末調整の中村▼は未研修に入る" do
    seed
    cards = TrainingBoard.cards.index_by { |card| card.operation.name }

    expect(cards.fetch("勤怠の締め").trainers.map(&:name)).to eq [ "山本 直子", "小林 由美", "中村 健太", "管理者" ]
    expect(cards.fetch("年末調整").trainee_skills.map { |skill| skill.user.name }).to include("中村 健太")
  end

  it "再実行しても重複せず、デモ中の変更と記録を保持する" do
    seed
    skill = Skill.find_by!(user: User.find_by!(name: "吉田 あかり"), operation: Operation.find_by!(name: "給与計算"))
    Skill.transaction do
      skill.update!(level: 3)
      skill.skill_level_changes.create!(from_level: 1, to_level: 3, reason: :self_declared, changed_by: skill.user)
    end
    models = [ User, Category, Operation, Manual, Skill, ManualRevision, Training, SkillLevelChange ]
    before = models.map { |model| model.order(:id).map(&:attributes) }

    seed

    expect(models.map { |model| model.order(:id).map(&:attributes) }).to eq(before)
  end
end
