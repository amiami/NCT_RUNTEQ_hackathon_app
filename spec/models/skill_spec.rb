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
end
