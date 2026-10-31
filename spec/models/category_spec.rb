require "rails_helper"

RSpec.describe Category do
  describe "バリデーション" do
    it "名前と表示順があれば保存できる" do
      expect(build(:category)).to be_valid
    end

    it "名前が空だと保存できない" do
      expect(build(:category, name: "")).not_to be_valid
    end

    it "表示順が空だと保存できない" do
      expect(build(:category, sort_order: nil)).not_to be_valid
    end

    it "同じ名前の分類を2つ作れない" do
      create(:category, name: "入退社")

      expect(build(:category, name: "入退社")).not_to be_valid
    end
  end

  it "DB でも同じ名前の分類を2つ作れない" do
    create(:category, name: "入退社")
    duplicate = build(:category, name: "入退社")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
