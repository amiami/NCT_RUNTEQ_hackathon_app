require "rails_helper"

RSpec.describe "アプリ内マニュアルの改定" do
  let!(:manager) { create(:user, :admin) }
  let!(:manual) { create(:manual, body: "古い手順\n確認する") }
  let(:operation) { manual.operation }

  def revise(body: "新しい手順", version: 1)
    patch admin_operation_manual_path(operation), params: {
      manual: { body: body, memo: "書類を変更", version: version, user_id: -1, kind: "external" }
    }
  end

  it "管理者の内部マニュアルに編集リンクがあり、現在の手順が入った編集欄を開く" do
    get admin_operations_path, params: { operation_id: operation.id }
    expect(Capybara.string(response.body)).to have_link("手順を書き直す（改定）", href: edit_admin_operation_manual_path(operation))
    get edit_admin_operation_manual_path(operation)
    expect(response).to have_http_status(:ok)
    expect(Capybara.string(response.body)).to have_field("手順（1行＝1ステップ）", with: manual.body)
    expect(Capybara.string(response.body)).to have_field("改定メモ")
  end

  it "保存後は選択した作業に戻り、版・改定日・手順が反映される" do
    travel_to Time.zone.local(2026, 11, 2, 10) do
      expect { revise }.to change(ManualRevision, :count).by(1)
      expect(response).to redirect_to(admin_operations_path(operation_id: operation.id))
      expect(response).to have_http_status(:see_other)
      expect(manual.reload).to have_attributes(body: "新しい手順", version: 2, kind: "internal")
      expect(manual.manual_revisions.sole.user).to eq(manager)
      follow_redirect!
      expect(Capybara.string(response.body)).to have_css("li", text: "新しい手順")
      expect(response.body).to include("第2版", "最終改定：2026/11/02")
    end
  end

  it "空の手順は保存せず、入力したメモとエラーを表示する" do
    expect { revise(body: "  \n") }.not_to change(ManualRevision, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(Capybara.string(response.body)).to have_css("[role='alert']", text: "手順を入力してください")
    expect(Capybara.string(response.body)).to have_field("改定メモ", with: "書類を変更")
    expect(manual.reload.version).to eq(1)
  end

  it "編集中に改定されたら古い入力で上書きしない" do
    revise
    revise(body: "上書き")
    expect(response).to have_http_status(:conflict)
    expect(manual.reload).to have_attributes(body: "新しい手順", version: 2)
    expect(manual.manual_revisions.count).to eq(1)
  end

  it "スタッフには編集リンクがなく、直接開いても更新しても改定できない" do
    staff = create(:user)
    patch operator_path, params: { user_id: staff.id }
    get staff_operations_path, params: { operation_id: operation.id }
    expect(response.body).not_to include(edit_admin_operation_manual_path(operation))
    get edit_admin_operation_manual_path(operation)
    expect(response).to redirect_to(staff_operations_path)
    expect { revise }.not_to change(ManualRevision, :count)
    expect(response).to redirect_to(staff_operations_path)
    expect(manual.reload).to have_attributes(body: "古い手順\n確認する", version: 1)
  end

  it "外部サイトには手順の編集リンクがなく、編集画面は開けない" do
    manual.update!(kind: :external, url: "https://example.com")
    get admin_operations_path, params: { operation_id: operation.id }
    expect(response.body).not_to include(edit_admin_operation_manual_path(operation))
    get edit_admin_operation_manual_path(operation)
    expect(response).to have_http_status(:not_found)
  end

  it "マニュアル未登録の作業は404になる" do
    get edit_admin_operation_manual_path(create(:operation))
    expect(response).to have_http_status(:not_found)
  end
end
