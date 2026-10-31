require "rails_helper"

RSpec.describe SkillLevelChange do
  describe "バリデーション" do
    it "Skill・操作した人・変更前後のレベル・理由があれば保存できる" do
      expect(build(:skill_level_change)).to be_valid
    end

    it "reason は4つのどれかなら保存できる" do
      %w[confirmed trained self_declared declaration_undone].each do |reason|
        expect(build(:skill_level_change, reason:)).to be_valid
      end
    end

    it "reason が4つ以外だと保存できない" do
      expect(build(:skill_level_change, reason: "unknown")).not_to be_valid
    end

    it "reason が空だと保存できない" do
      expect(build(:skill_level_change, reason: nil)).not_to be_valid
    end

    it "変更前・変更後のレベルが空だと保存できない" do
      expect(build(:skill_level_change, from_level: nil)).not_to be_valid
      expect(build(:skill_level_change, to_level: nil)).not_to be_valid
    end

    it "操作した人がいないと保存できない" do
      expect(build(:skill_level_change, changed_by: nil)).not_to be_valid
    end
  end

  it "Skill からレベル変更の記録をたどれる" do
    change = create(:skill_level_change)

    expect(change.skill.skill_level_changes).to contain_exactly(change)
  end
end
