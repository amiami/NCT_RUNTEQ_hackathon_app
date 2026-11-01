require "rails_helper"

RSpec.describe Skills::AssessmentUpdate do
  let(:admin) { create(:user, :admin) }

  # assessments は { スキルの ID => 見立て（"" は「なし」） }。画面から送られる形と同じ
  def update(assessments)
    described_class.new(admin:, assessments:)
  end

  describe "AC-1: 付けられるレベルなら保存できる" do
    it "レベル3に▲を付けられる" do
      skill = create(:skill, level: 3)

      expect(update(skill.id => "can_train").save).to be true
      expect(skill.reload.admin_assessment).to eq "can_train"
    end

    it "レベル3に▼を付けられる" do
      skill = create(:skill, level: 3)

      expect(update(skill.id => "needs_training").save).to be true
      expect(skill.reload.admin_assessment).to eq "needs_training"
    end

    it "レベル4に◇を付けられる" do
      skill = create(:skill, level: 4)

      expect(update(skill.id => "backup_trainer").save).to be true
      expect(skill.reload.admin_assessment).to eq "backup_trainer"
    end

    it "別の見立てを選ぶと置き換わる（▽の人に▲）" do
      skill = create(:skill, level: 3, admin_assessment: :training_done)

      expect(update(skill.id => "can_train").save).to be true
      expect(skill.reload.admin_assessment).to eq "can_train"
    end
  end

  describe "AC-2: 付けられない組み合わせは保存できない" do
    {
      [ 3, "backup_trainer" ] => "レベル3に◇",
      [ 4, "can_train" ] => "レベル4に▲",
      [ 4, "needs_training" ] => "レベル4に▼",
      [ 0, "can_train" ] => "レベル0に▲",
      [ 1, "needs_training" ] => "レベル1に▼",
      [ 2, "backup_trainer" ] => "レベル2に◇",
      [ 3, "training_done" ] => "▽を手で付ける（▽は「教え終わった」で自動で付く）",
      [ 3, "unknown" ] => "見立てにない値"
    }.each do |(level, assessment), label|
      it "#{label}は保存されない" do
        skill = create(:skill, level:)
        service = update(skill.id => assessment)

        expect(service.save).to be false
        expect(service.errors).to be_present
        expect(skill.reload.admin_assessment).to be_nil
      end
    end
  end

  describe "AC-3: 複数のマスをまとめて保存する" do
    let(:yamamoto) { create(:user) }
    let(:nakamura) { create(:user) }
    let!(:yamamoto_first) { create(:skill, user: yamamoto, level: 3) }
    let!(:yamamoto_second) { create(:skill, user: yamamoto, level: 4) }
    let!(:nakamura_first) { create(:skill, user: nakamura, level: 3) }

    it "同じ人の複数の作業と、別の人の作業を、まとめて保存できる" do
      service = update(
        yamamoto_first.id => "can_train",
        yamamoto_second.id => "backup_trainer",
        nakamura_first.id => "needs_training"
      )

      expect(service.save).to be true
      expect(yamamoto_first.reload.admin_assessment).to eq "can_train"
      expect(yamamoto_second.reload.admin_assessment).to eq "backup_trainer"
      expect(nakamura_first.reload.admin_assessment).to eq "needs_training"
    end

    it "1つでも付けられない組み合わせがあれば、全部保存しない" do
      service = update(
        yamamoto_first.id => "can_train",
        yamamoto_second.id => "can_train", # レベル4に▲は付けられない
        nakamura_first.id => "needs_training"
      )

      expect(service.save).to be false
      expect([ yamamoto_first, yamamoto_second, nakamura_first ].map { |skill| skill.reload.admin_assessment }).to all(be_nil)
    end
  end

  describe "AC-4: 付けた人と日時を記録する" do
    it "admin_assessed_at に今の日時、admin_assessed_by に保存した管理者が入る" do
      skill = create(:skill, level: 3)

      travel_to Time.zone.local(2026, 11, 1, 10, 0) do
        update(skill.id => "can_train").save
      end

      skill.reload
      expect(skill.admin_assessed_at).to eq Time.zone.local(2026, 11, 1, 10, 0)
      expect(skill.admin_assessed_by).to eq admin
    end

    it "値が変わらないマスは、日時と付けた人を更新しない" do
      other_admin = create(:user, :admin)
      skill = create(:skill, level: 3, admin_assessment: :can_train,
                             admin_assessed_at: Time.zone.local(2026, 10, 20), admin_assessed_by: other_admin)

      travel_to Time.zone.local(2026, 11, 1, 10, 0) do
        expect(update(skill.id => "can_train").save).to be true
      end

      skill.reload
      expect(skill.admin_assessed_at).to eq Time.zone.local(2026, 10, 20)
      expect(skill.admin_assessed_by).to eq other_admin
    end
  end

  describe "AC-5: 「なし」を選ぶと見立てが外れる" do
    {
      [ 3, :can_train ] => "3▲",
      [ 4, :can_train ] => "4▲（今のレベルで意味のない見立て）",
      [ 4, :training_done ] => "4▽（今のレベルで意味のない見立て）",
      [ 3, :backup_trainer ] => "3◇（今のレベルで意味のない見立て）"
    }.each do |(level, assessment), label|
      it "#{label}の人も、見立て・日時・付けた人が空になる" do
        skill = create(:skill, level:, admin_assessment: assessment,
                               admin_assessed_at: Time.zone.local(2026, 10, 20), admin_assessed_by: admin)

        expect(update(skill.id => "").save).to be true

        skill.reload
        expect(skill.admin_assessment).to be_nil
        expect(skill.admin_assessed_at).to be_nil
        expect(skill.admin_assessed_by).to be_nil
      end
    end
  end

  describe "AC-6: レベルは変えない" do
    it "skill_level_changes が増えず、レベルも変わらない" do
      skill = create(:skill, level: 3)

      expect { update(skill.id => "needs_training").save }.not_to change(SkillLevelChange, :count)
      expect(skill.reload.level).to eq 3
    end

    it "「なし」で外したときも、skill_level_changes が増えない" do
      skill = create(:skill, level: 4, admin_assessment: :backup_trainer)

      expect { update(skill.id => "").save }.not_to change(SkillLevelChange, :count)
      expect(skill.reload.level).to eq 4
    end
  end

  describe "AC-8: 値が変わらないマスは、レベルを確かめない" do
    it "4▲の人を▲のまま、ほかのマスと一緒に保存しても、エラーにならない" do
      hidden = create(:skill, level: 4, admin_assessment: :can_train)
      other = create(:skill, level: 3)
      service = update(hidden.id => "can_train", other.id => "needs_training")

      expect(service.save).to be true
      expect(service.errors).to be_empty
      expect(hidden.reload.admin_assessment).to eq "can_train"
      expect(other.reload.admin_assessment).to eq "needs_training"
    end
  end
end
