require "rails_helper"

RSpec.describe SelfDeclaration do
  let(:user) { create(:user) }
  let(:operation) { create(:operation) }
  let!(:skill) { create(:skill, user:, operation:, level: 1) }

  def declare(level, by: user)
    described_class.call(user: by, operation:, level:)
  end

  describe "AC-1: 「先輩のもとでできる」でレベル3になる" do
    [ 1, 2, 4 ].each do |from|
      it "レベル#{from}からレベル3になる" do
        skill.update!(level: from)

        declare(3)

        expect(skill.reload.level).to eq 3
      end
    end
  end

  describe "AC-2: 「最後まで1人でできる」でレベル4になる" do
    [ 1, 2, 3 ].each do |from|
      it "レベル#{from}からレベル4になる（3を飛ばせる）" do
        skill.update!(level: from)

        declare(4)

        expect(skill.reload.level).to eq 4
      end
    end
  end

  describe "AC-3: 申告できないとき" do
    it "レベル0のときは、どちらも申告できない（先にマニュアルの確認が必要）" do
      skill.update!(level: 0)

      [ 3, 4 ].each do |level|
        expect { declare(level) }.to raise_error(SelfDeclaration::NotDeclarable)
      end
      expect(skill.reload.level).to eq 0
    end

    it "その作業のスキルがまだない（一度も確認していない）ときは申告できず、スキルも作らない" do
      other_operation = create(:operation)

      expect { described_class.call(user:, operation: other_operation, level: 3) }
        .to raise_error(SelfDeclaration::NotDeclarable)
      expect(user.skills.where(operation: other_operation)).to be_empty
    end

    it "レベル3・4以外には申告できない（0〜2へ下げる操作はない）" do
      skill.update!(level: 4)

      [ 0, 1, 2, 5, nil ].each do |level|
        expect { declare(level) }.to raise_error(SelfDeclaration::NotDeclarable)
      end
      expect(skill.reload.level).to eq 4
    end
  end

  it "AC-4: 研修を受けていなくても申告できる" do
    expect(Training.where(trainee: user)).to be_empty

    declare(4)

    expect(skill.reload.level).to eq 4
  end

  describe "AC-5: レベルの変更を記録する" do
    it "skill_level_changes が1件増える（元のレベル・新しいレベル・自己申告・操作した人）" do
      skill.update!(level: 2)

      expect { declare(3) }.to change(SkillLevelChange, :count).by(1)

      expect(skill.skill_level_changes.sole).to have_attributes(
        from_level: 2, to_level: 3, reason: "self_declared", changed_by: user)
    end

    it "記録の保存に失敗したら、レベルも変えない（1つのトランザクション）" do
      allow(SkillLevelChange).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(SkillLevelChange.new))

      expect { declare(3) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(skill.reload.level).to eq 1
    end
  end

  it "AC-6: 申告しても、管理者の見立てと確認した版は変わらない" do
    admin = create(:user, :admin)
    assessed_at = Time.zone.local(2026, 10, 1, 9, 0)
    skill.update!(level: 3, confirmed_version: 2, admin_assessment: :can_train,
                  admin_assessed_at: assessed_at, admin_assessed_by: admin)

    declare(4)

    expect(skill.reload).to have_attributes(
      level: 4, confirmed_version: 2, admin_assessment: "can_train",
      admin_assessed_at: assessed_at, admin_assessed_by: admin)
  end

  it "AC-7: 管理者は申告できない" do
    admin = create(:user, :admin)

    expect { declare(3, by: admin) }.to raise_error(SelfDeclaration::NotStaff)
    expect(skill.reload.level).to eq 1
  end

  it "すでにそのレベルなら何も変えず、記録も増やさない（ボタンの2回押し）" do
    declare(3)

    expect { declare(3) }.not_to change(SkillLevelChange, :count)
    expect(skill.reload.level).to eq 3
  end
end
