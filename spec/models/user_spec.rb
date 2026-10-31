require "rails_helper"

RSpec.describe User do
  describe "バリデーション" do
    it "名前と表示順があれば保存できる" do
      expect(build(:user)).to be_valid
    end

    it "名前が空だと保存できない" do
      expect(build(:user, name: "")).not_to be_valid
    end

    it "表示順が空だと保存できない" do
      expect(build(:user, sort_order: nil)).not_to be_valid
    end
  end

  it "admin の既定値は false" do
    expect(described_class.new.admin).to be false
  end

  describe ".skill_holders" do
    it "管理者は入らず、スタッフだけが入る" do
      admin = create(:user, :admin)
      staff = create(:user)

      expect(described_class.skill_holders).to contain_exactly(staff)
      expect(described_class.skill_holders).not_to include(admin)
    end
  end
end
