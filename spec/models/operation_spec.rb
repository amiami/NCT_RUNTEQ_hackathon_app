require "rails_helper"

RSpec.describe Operation do
  describe "バリデーション" do
    it "分類・名前・表示順があれば保存できる" do
      expect(build(:operation)).to be_valid
    end

    it "時期の目安は空でも保存できる" do
      expect(build(:operation, season_note: nil)).to be_valid
    end

    it "名前が空だと保存できない" do
      expect(build(:operation, name: "")).not_to be_valid
    end

    it "表示順が空だと保存できない" do
      expect(build(:operation, sort_order: nil)).not_to be_valid
    end

    it "分類がないと保存できない" do
      expect(build(:operation, category: nil)).not_to be_valid
    end

    it "同じ分類に同じ名前の作業を2つ作れない" do
      category = create(:category)
      create(:operation, category:, name: "年末調整")

      expect(build(:operation, category:, name: "年末調整")).not_to be_valid
    end

    it "別の分類なら同じ名前の作業を作れる" do
      create(:operation, name: "年末調整")

      expect(build(:operation, name: "年末調整")).to be_valid
    end
  end

  it "DB でも同じ分類に同じ名前の作業を2つ作れない" do
    category = create(:category)
    create(:operation, category:, name: "年末調整")
    duplicate = build(:operation, category:, name: "年末調整")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "#capable_count" do
    it "その作業でレベル4の人数を返す（◇・▼の人も数える）" do
      operation = create(:operation)
      create(:skill, operation:, level: 4)
      create(:skill, operation:, level: 4, admin_assessment: :backup_trainer)
      create(:skill, operation:, level: 4, admin_assessment: :needs_training)
      create(:skill, operation:, level: 3, admin_assessment: :can_train)
      create(:skill, operation:, level: 0)
      create(:skill, level: 4)

      expect(operation.capable_count).to eq 3
    end

    it "レベル4の人がいなければ 0" do
      operation = create(:operation)
      create(:skill, operation:, level: 3)

      expect(operation.capable_count).to eq 0
    end
  end
end
