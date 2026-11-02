require "rails_helper"

RSpec.describe "外部サイトの改定あり" do
  let!(:manager) { create(:user, :admin) }
  let!(:manual) { create(:manual, :external) }
  let(:operation) { manual.operation }

  def revise(version: 1, memo: "法改正に合わせて様式が更新された")
    patch admin_operation_manual_path(operation), params: {
      manual: { version: version, memo: memo, url: "https://example.com/changed",
        body: "書き換え", user_id: -1, kind: "internal" }
    }
  end

  it "管理者だけに変更内容のメモ欄と改定ありボタンを表示する" do
    get admin_operations_path, params: { operation_id: operation.id }
    document = Capybara.string(response.body)
    expect(document).to have_field("法改正・様式・サイトに変更があったとき")
    expect(document).to have_button("改定あり")
    expect(document).to have_no_field("手順（1行＝1ステップ）")
    expect(document).to have_no_css("input[name='manual[url]']")
  end

  it "メモと改定者を記録し、URLと本文を保って版だけを上げる" do
    travel_to Time.zone.local(2026, 11, 2, 15) do
      expect { revise }.to change(ManualRevision, :count).by(1)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(admin_operations_path(operation_id: operation.id))
      expect(manual.reload).to have_attributes(version: 2, url: "https://example.com/manual", body: nil, kind: "external")
      expect(manual.manual_revisions.sole).to have_attributes(version: 2, user: manager,
        memo: "法改正に合わせて様式が更新された", created_at: Time.current, body_before: nil, body_after: nil)
      follow_redirect!
      expect(response.body).to include("第2版", "最終改定：2026/11/02")
    end
  end

  it "空メモでも改定できる" do
    expect { revise(memo: "") }.to change(ManualRevision, :count).by(1)
    expect(manual.manual_revisions.sole.memo).to eq("")
  end

  it "スタッフにはボタンもメモ欄も出さず、直接送信も拒否する" do
    patch operator_path, params: { user_id: create(:user).id }
    get staff_operations_path, params: { operation_id: operation.id }
    expect(Capybara.string(response.body)).to have_no_button("改定あり")
    expect(Capybara.string(response.body)).to have_no_css("input[name='manual[memo]']")
    expect { revise }.not_to change(ManualRevision, :count)
    expect(response).to redirect_to(staff_operations_path)
    expect(manual.reload.version).to eq(1)
  end

  it "二重送信は改定を増やさず、最新表示に戻して案内する" do
    revise
    expect { revise }.not_to change(ManualRevision, :count)
    expect(response).to redirect_to(admin_operations_path(operation_id: operation.id))
    follow_redirect!
    expect(response.body).to include("マニュアルが更新されました")
    expect(manual.reload.version).to eq(2)
  end
end
