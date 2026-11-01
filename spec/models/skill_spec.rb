require "rails_helper"

RSpec.describe Skill do
  describe "バリデーション" do
    it "スタッフと作業があれば保存できる" do
      expect(build(:skill)).to be_valid
    end

    it "level の既定値は 0" do
      expect(described_class.new.level).to eq 0
    end

    it "level が 0〜4 なら保存できる" do
      (0..4).each do |level|
        expect(build(:skill, level:)).to be_valid
      end
    end

    it "level が 0〜4 以外だと保存できない" do
      [ -1, 5, nil ].each do |level|
        expect(build(:skill, level:)).not_to be_valid
      end
    end

    it "level が整数でないと保存できない" do
      expect(build(:skill, level: 1.5)).not_to be_valid
    end

    it "同じ人×作業の Skill を2つ作れない" do
      skill = create(:skill)

      expect(build(:skill, user: skill.user, operation: skill.operation)).not_to be_valid
    end

    it "同じ人でも別の作業なら作れる" do
      skill = create(:skill)

      expect(build(:skill, user: skill.user)).to be_valid
    end

    it "管理者の Skill は作れない" do
      skill = build(:skill, user: build(:user, :admin))

      expect(skill).not_to be_valid
      expect(skill.errors).to be_added(:user, :not_skill_holder)
    end
  end

  it "DB でも同じ人×作業の Skill を2つ作れない" do
    skill = create(:skill)
    duplicate = build(:skill, user: skill.user, operation: skill.operation)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "管理者の見立て" do
    it "4つの値を保存できる" do
      admin = create(:user, :admin)

      %w[can_train needs_training training_done backup_trainer].each do |assessment|
        skill = create(:skill, level: 3, admin_assessment: assessment, admin_assessed_at: Time.current, admin_assessed_by: admin)

        expect(skill.reload.admin_assessment).to eq assessment
      end
    end

    it "なし（NULL）でも保存できる" do
      expect(create(:skill, admin_assessment: nil).reload.admin_assessment).to be_nil
    end

    it "4つ以外の値だと保存できない" do
      expect(build(:skill, admin_assessment: "unknown")).not_to be_valid
    end

    it "見立てに合わないレベルでも保存できる（レベルとの組み合わせは付けるときのサービスで確かめる）" do
      expect(build(:skill, level: 0, admin_assessment: :can_train)).to be_valid
    end

    describe "#assessment_meaningful?（今のレベルで意味のある見立てか）" do
      meaningful = {
        3 => %w[can_train needs_training training_done], # ▲・▼・▽
        4 => %w[needs_training backup_trainer]           # ▼・◇
      }

      # レベル0〜4 × 見立て（なし・4種類）の全組み合わせと、期待する結果
      cases = (0..4).to_a.product([ nil, *described_class.admin_assessments.keys ]).map do |level, assessment|
        [ level, assessment, meaningful.fetch(level, []).include?(assessment) ]
      end

      cases.each do |level, assessment, expected|
        it "レベル#{level}・見立て #{assessment || 'なし'} は #{expected}" do
          skill = build(:skill, level:, admin_assessment: assessment)

          expect(skill.assessment_meaningful?).to be expected
        end
      end
    end
  end

  describe "#unread?" do
    let(:operation) { create(:operation) }
    let!(:manual) { create(:manual, operation:) }

    it "一度も確認していない人は false" do
      skill = create(:skill, operation:, confirmed_version: nil)
      manual.update!(version: 2)

      expect(skill.unread?).to be false
    end

    it "今の版を確認した人は false" do
      expect(create(:skill, operation:, confirmed_version: 1).unread?).to be false
    end

    it "版が上がると、前に確認した人は true になる" do
      skill = create(:skill, operation:, confirmed_version: 1)
      manual.update!(version: 2)

      expect(skill.reload.unread?).to be true
    end
  end

  describe "できる人" do
    let(:operation) { create(:operation) }

    before do
      create(:skill, operation:, level: 4)
      create(:skill, operation:, level: 4, admin_assessment: :backup_trainer)
      create(:skill, operation:, level: 4, admin_assessment: :needs_training)
      create(:skill, operation:, level: 3, admin_assessment: :can_train)
      # 管理者の Skill はバリデーションで作れないが、入っていても数えないことを確かめる
      build(:skill, operation:, level: 4, user: create(:user, :admin)).save!(validate: false)
    end

    describe ".capable" do
      it "スキルを持つ人のうち、レベル4の Skill だけを返す（◇・▼の人も含む）" do
        expect(described_class.capable.map(&:level)).to eq [ 4, 4, 4 ]
        expect(described_class.capable.map(&:user)).to all(satisfy { |user| !user.admin? })
      end
    end

    describe ".capable_counts" do
      it "作業ごとのできる人の数を返す" do
        other = create(:operation)
        create(:skill, operation: other, level: 4)

        expect(described_class.capable_counts).to eq(operation.id => 3, other.id => 1)
      end

      it "できる人がいない作業は含まない" do
        nobody = create(:operation)
        create(:skill, operation: nobody, level: 3)

        expect(described_class.capable_counts).not_to have_key(nobody.id)
      end

      it "作業の数によらず、クエリは1回" do
        create_list(:skill, 3, level: 4)

        queries = []
        callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          described_class.capable_counts
        end

        expect(queries.size).to eq 1
      end
    end
  end

  describe "研修の候補" do
    let(:operation) { create(:operation) }

    # 名前で結果を見やすくするため、レベルと見立てから名前を付ける
    def skill_with(level, assessment = nil, name:, sort_order:)
      create(:skill, operation:, level:, admin_assessment: assessment,
                     user: create(:user, name:, sort_order:))
    end

    def names(skills)
      skills.map { |skill| skill.user.name }
    end

    describe ".trainer_candidates" do
      before do
        skill_with(4, :backup_trainer, name: "4◇", sort_order: 1)
        skill_with(3, :can_train, name: "3▲", sort_order: 2)
        skill_with(4, :training_done, name: "4▽", sort_order: 3)
        skill_with(4, :can_train, name: "4▲", sort_order: 4)
        skill_with(4, nil, name: "4", sort_order: 5)
        skill_with(4, :needs_training, name: "4▼", sort_order: 6)
        skill_with(3, nil, name: "3", sort_order: 7)
        skill_with(3, :training_done, name: "3▽", sort_order: 8)
        skill_with(3, :needs_training, name: "3▼", sort_order: 9)
        skill_with(2, :can_train, name: "2▲", sort_order: 10)
        skill_with(1, nil, name: "1", sort_order: 11)
        skill_with(0, nil, name: "0", sort_order: 12)
      end

      it "レベル4（◇・▼以外）→ 3▲ → 4◇ の順に並び、同じグループの中はスタッフの並び順" do
        expect(names(described_class.trainer_candidates)).to eq [ "4▽", "4▲", "4", "3▲", "4◇" ]
      end

      it "4▼・▲のないレベル3・3▽・レベル0〜2は入らない" do
        expect(names(described_class.trainer_candidates)).not_to include("4▼", "3", "3▽", "3▼", "2▲", "1", "0")
      end

      it "管理者の Skill が入っていても候補にしない" do
        build(:skill, operation:, level: 4, user: create(:user, :admin, sort_order: 0)).save!(validate: false)

        expect(described_class.trainer_candidates.map(&:user)).to all(satisfy { |user| !user.admin? })
      end
    end

    describe ".training_targets" do
      before do
        skill_with(0, nil, name: "0", sort_order: 1)
        skill_with(1, nil, name: "1", sort_order: 2)
        skill_with(2, nil, name: "2", sort_order: 3)
        skill_with(3, nil, name: "3", sort_order: 4)
        skill_with(3, :can_train, name: "3▲", sort_order: 5)
        skill_with(3, :training_done, name: "3▽", sort_order: 6)
        skill_with(3, :needs_training, name: "3▼", sort_order: 7)
        skill_with(4, nil, name: "4", sort_order: 8)
        skill_with(4, :needs_training, name: "4▼", sort_order: 9)
      end

      it "レベル0・1の人と▼の人（4▼も含む）が、スタッフの並び順で入る" do
        expect(names(described_class.training_targets)).to eq [ "0", "1", "3▼", "4▼" ]
      end

      it "管理者の Skill が入っていても対象にしない" do
        build(:skill, operation:, level: 0, user: create(:user, :admin, sort_order: 0)).save!(validate: false)

        expect(described_class.training_targets.map(&:user)).to all(satisfy { |user| !user.admin? })
      end
    end
  end
end
