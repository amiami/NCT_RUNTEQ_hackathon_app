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

  describe ".few_capable_count（スキルマップのタブの件数）" do
    def operation_with_capable(count)
      create(:operation).tap do |operation|
        create_list(:skill, count, operation:, level: 4)
        create(:skill, operation:, level: 3)
      end
    end

    it "できる人が1人以下の作業の数を返す（0人の作業も数える）" do
      operation_with_capable(0)
      operation_with_capable(1)
      operation_with_capable(2)
      operation_with_capable(3)
      create(:operation) # スキルが1つもない作業も、できる人0人として数える

      expect(described_class.few_capable_count).to eq 3
    end

    it "◇・▼のレベル4もできる人に数え、管理者は数えない" do
      operation = create(:operation)
      create(:skill, operation:, level: 4, admin_assessment: :backup_trainer)
      create(:skill, operation:, level: 4, admin_assessment: :needs_training)
      admin_only = create(:operation)
      create(:skill, operation: admin_only, level: 4)
      build(:skill, operation: admin_only, level: 4, user: create(:user, :admin)).save!(validate: false)

      expect(described_class.few_capable_count).to eq 1
    end

    it "作業がなければ 0" do
      expect(described_class.few_capable_count).to eq 0
    end
  end
end
