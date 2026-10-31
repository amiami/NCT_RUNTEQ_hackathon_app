require "rails_helper"

RSpec.describe Manual do
  describe "バリデーション" do
    it "アプリ内のマニュアルは手順があれば保存できる" do
      expect(build(:manual)).to be_valid
    end

    it "外部サイトのマニュアルは URL があれば保存できる" do
      expect(build(:manual, :external)).to be_valid
    end

    it "kind が internal のとき body が空だと保存できない" do
      expect(build(:manual, kind: :internal, body: "")).not_to be_valid
    end

    it "kind が external のとき url が空だと保存できない" do
      expect(build(:manual, :external, url: "")).not_to be_valid
    end

    it "kind が internal なら url も入れられる" do
      expect(build(:manual, url: "https://example.com/reference")).to be_valid
    end

    it "1つの作業にマニュアルを2つ作れない" do
      operation = create(:operation)
      create(:manual, operation:)

      expect(build(:manual, operation:)).not_to be_valid
    end
  end

  it "DB でも1つの作業にマニュアルを2つ作れない" do
    operation = create(:operation)
    create(:manual, operation:)
    duplicate = build(:manual, operation:)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "version の既定値は 1" do
    expect(described_class.new.version).to eq 1
  end

  describe "#steps" do
    it "空行を除いた行の配列を返す" do
      manual = build(:manual, body: "書類を集める\n\n  \r\n内容を確かめる\r\n提出する\n")

      expect(manual.steps).to eq %w[書類を集める 内容を確かめる 提出する]
    end

    it "body が空なら空の配列を返す" do
      expect(build(:manual, :external).steps).to eq []
    end
  end
end
