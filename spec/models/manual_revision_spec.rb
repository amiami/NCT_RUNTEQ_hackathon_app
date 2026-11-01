require "rails_helper"

RSpec.describe ManualRevision do
  describe "バリデーション" do
    it "マニュアル・改定した人・版があれば保存できる" do
      expect(build(:manual_revision)).to be_valid
    end

    it "メモ・変更前後の手順は空でも保存できる" do
      expect(build(:manual_revision, memo: nil, body_before: nil, body_after: nil)).to be_valid
    end

    it "マニュアルがないと保存できない" do
      expect(build(:manual_revision, manual: nil)).not_to be_valid
    end

    it "改定した人がいないと保存できない" do
      expect(build(:manual_revision, user: nil)).not_to be_valid
    end

    it "版が空だと保存できない" do
      expect(build(:manual_revision, version: nil)).not_to be_valid
    end

    it "初版（第1版）の行は作れない" do
      expect(build(:manual_revision, version: 1)).not_to be_valid
    end

    it "同じマニュアルに同じ版の改訂履歴を2つ作れない" do
      revision = create(:manual_revision)

      expect(build(:manual_revision, manual: revision.manual, version: revision.version)).not_to be_valid
    end

    it "別のマニュアルなら同じ版を作れる" do
      create(:manual_revision, version: 2)

      expect(build(:manual_revision, version: 2)).to be_valid
    end
  end

  it "DB でも同じマニュアルに同じ版の改訂履歴を2つ作れない" do
    revision = create(:manual_revision)
    duplicate = build(:manual_revision, manual: revision.manual, version: revision.version)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "マニュアルから改訂履歴をたどれる" do
    revision = create(:manual_revision)

    expect(revision.manual.manual_revisions).to contain_exactly(revision)
  end
end
