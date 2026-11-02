require "rails_helper"

RSpec.describe ManualConfirmation do
  let(:user) { create(:user) }
  let(:manual) { create(:manual, version: 2) }
  let!(:skill) { create(:skill, user: user, operation: manual.operation) }

  def confirm(version: manual.version)
    described_class.call(user: user, operation: manual.operation, version: version)
  end

  it "レベル0を1にし、確認した版と本人の変更履歴をまとめて保存する" do
    expect { confirm }.to change(SkillLevelChange, :count).by(1)

    expect(skill.reload).to have_attributes(level: 1, confirmed_version: 2)
    expect(skill.skill_level_changes.sole).to have_attributes(
      from_level: 0, to_level: 1, reason: "confirmed", changed_by: user)
  end

  it "レベル1〜4は下げず、確認した版だけを更新する" do
    (1..4).each do |level|
      skill.update!(level: level, confirmed_version: 1)

      expect { confirm }.not_to change(SkillLevelChange, :count)
      expect(skill.reload).to have_attributes(level: level, confirmed_version: 2)
    end
  end

  it "同じ版を二度確認しても変更履歴を重複させない" do
    confirm

    expect { confirm }.not_to change(SkillLevelChange, :count)
    expect(skill.reload).to have_attributes(level: 1, confirmed_version: 2)
  end

  it "履歴の保存に失敗したら、確認した版もレベルも保存しない" do
    allow(SkillLevelChange).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(SkillLevelChange.new))

    expect { confirm }.to raise_error(ActiveRecord::RecordInvalid)
    expect(skill.reload).to have_attributes(level: 0, confirmed_version: nil)
    expect(skill.skill_level_changes).to be_empty
  end

  it "管理者の見立てとその記録を変えない" do
    manager = create(:user, :admin)
    assessed_at = Time.zone.local(2026, 10, 20, 12)
    skill.update!(level: 3, admin_assessment: :needs_training, admin_assessed_by: manager, admin_assessed_at: assessed_at)

    confirm

    expect(skill.reload).to have_attributes(level: 3, confirmed_version: 2,
      admin_assessment: "needs_training", admin_assessed_by: manager, admin_assessed_at: assessed_at)
  end

  it "管理者は確認できず、スキルも作らない" do
    manager = create(:user, :admin)

    expect do
      described_class.call(user: manager, operation: manual.operation, version: manual.version)
    end.to raise_error(described_class::NotStaff)
    expect(manager.skills).to be_empty
  end

  it "画面を開いた後に版が上がっていたら、新しい版を確認済みにしない" do
    expect { confirm(version: 1) }.to raise_error(described_class::StaleVersion)
    expect(skill.reload).to have_attributes(level: 0, confirmed_version: nil)
    expect(skill.skill_level_changes).to be_empty
  end

  it "スキル未作成なら、本人のスキルとレベル0から1への履歴を作る" do
    other_user = create(:user)

    expect do
      described_class.call(user: other_user, operation: manual.operation, version: manual.version)
    end.to change(Skill, :count).by(1).and change(SkillLevelChange, :count).by(1)
    expect(other_user.skills.sole).to have_attributes(operation: manual.operation, level: 1, confirmed_version: 2)
  end

  it "マニュアルがない作業ではスキルや履歴を作らない" do
    operation = create(:operation)

    expect do
      described_class.call(user: user, operation: operation, version: 1)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.skills.where(operation: operation)).to be_empty
  end
end
