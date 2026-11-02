require "rails_helper"

RSpec.describe ManualReviser do
  let(:manager) { create(:user, :admin) }
  let(:manual) { create(:manual, body: "古い手順", version: 1) }

  def revise(user: manager, body: "新しい手順\n確認する", version: 1, memo: "手順を更新")
    described_class.call(user: user, manual: manual, body: body, memo: memo, version: version)
  end

  it "本文と版を更新し、日本時間の日付・変更者・変更前後を1件記録する" do
    travel_to Time.zone.local(2026, 11, 2, 10) do
      expect { revise }.to change(ManualRevision, :count).by(1)
      expect(manual.reload).to have_attributes(body: "新しい手順\n確認する", version: 2)
      expect(manual.manual_revisions.sole).to have_attributes(user: manager, version: 2,
        memo: "手順を更新", body_before: "古い手順", body_after: "新しい手順\n確認する", created_at: Time.current)
    end
  end

  it "メモが空でも保存できる" do
    revise(memo: "")
    expect(manual.manual_revisions.sole.memo).to eq("")
  end

  it "全スキルのレベル・見立て・確認版と変更履歴を変えない" do
    create(:skill, operation: manual.operation, level: 3, confirmed_version: 1,
      admin_assessment: :needs_training, admin_assessed_by: manager, admin_assessed_at: Time.current)
    create(:skill, operation: manual.operation, level: 0)
    before = Skill.order(:id).map(&:attributes)

    expect { revise }.not_to change(SkillLevelChange, :count)
    expect(Skill.order(:id).map(&:attributes)).to eq(before)
  end

  [ "", " \n　\n" ].each do |body|
    it "空の手順#{body.inspect}を保存しない" do
      expect { revise(body: body) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(manual.reload).to have_attributes(body: "古い手順", version: 1)
      expect(manual.manual_revisions).to be_empty
    end
  end

  it "履歴の保存に失敗したら本文と版も戻す" do
    allow(ManualRevision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    expect { revise }.to raise_error(ActiveRecord::RecordInvalid)
    expect(manual.reload).to have_attributes(body: "古い手順", version: 1)
    expect(manual.manual_revisions).to be_empty
  end

  it "古い編集画面からの再送で上書きや重複改定をしない" do
    revise
    expect { revise }.to raise_error(described_class::StaleVersion)
    expect(manual.reload.version).to eq(2)
    expect(manual.manual_revisions.count).to eq(1)
  end

  it "スタッフと未選択のユーザーは改定できない" do
    [ create(:user), nil ].each do |user|
      expect { revise(user: user) }.to raise_error(described_class::NotAdmin)
    end
    expect(manual.reload.version).to eq(1)
    expect(manual.manual_revisions).to be_empty
  end

  context "外部サイト" do
    let(:manual) { create(:manual, :external) }

    it "URLと本文を変えずに版を上げ、本文の差分なしで履歴を残す" do
      original_url = manual.url
      expect { revise }.to change(ManualRevision, :count).by(1)
      expect(manual.reload).to have_attributes(version: 2, url: original_url, body: nil)
      expect(manual.manual_revisions.sole).to have_attributes(user: manager, version: 2,
        memo: "手順を更新", body_before: nil, body_after: nil)
    end

    it "レベル・見立て・確認版とレベル変更履歴は変わらない" do
      create(:skill, operation: manual.operation, level: 3, confirmed_version: 1,
        admin_assessment: :needs_training, admin_assessed_by: manager, admin_assessed_at: Time.current)
      before = Skill.order(:id).map(&:attributes)
      expect { revise }.not_to change(SkillLevelChange, :count)
      expect(Skill.order(:id).map(&:attributes)).to eq(before)
    end

    it "履歴保存に失敗したら版も元に戻る" do
      allow(ManualRevision).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      expect { revise }.to raise_error(ActiveRecord::RecordInvalid)
      expect(manual.reload.version).to eq(1)
      expect(manual.manual_revisions).to be_empty
    end

    it "スタッフは外部サイトも改定できない" do
      expect { revise(user: create(:user)) }.to raise_error(described_class::NotAdmin)
      expect(manual.reload.version).to eq(1)
    end

    it "古い版の再送では改訂記録を重複させない" do
      revise
      expect { revise }.to raise_error(described_class::StaleVersion)
      expect(manual.manual_revisions.count).to eq(1)
    end

    it "メモが空でも保存できる" do
      revise(memo: "")
      expect(manual.manual_revisions.sole.memo).to eq("")
    end
  end
end
