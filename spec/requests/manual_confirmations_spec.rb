require "rails_helper"

RSpec.describe "マニュアルの確認" do
  let(:staff) { create(:user) }
  let(:manual) { create(:manual) }
  let!(:skill) { create(:skill, user: staff, operation: manual.operation) }

  before { create(:user, :admin) }

  def document
    Capybara.string(response.body)
  end

  def switch_to(user)
    patch operator_path, params: { user_id: user.id }
  end

  def confirm(params = {})
    post staff_operation_confirmation_path(manual.operation), params: { version: manual.version }.merge(params)
  end

  it "AC-1・3・5: 確認すると本人がレベル1になり、選択した作業とツリーも更新される" do
    switch_to(staff)
    get staff_operations_path, params: { operation_id: manual.operation_id }
    expect(document).to have_button("マニュアルを確認した", disabled: false)
    expect(document).to have_css(".operation-confirmation-level", text: "未着手")

    expect { confirm }.to change(SkillLevelChange, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(staff_operations_path(operation_id: manual.operation_id))
    expect(skill.reload).to have_attributes(level: 1, confirmed_version: 1)
    follow_redirect!
    expect(document.find("a[href*='operation_id=#{manual.operation_id}']")).to have_text("レベル1")
    expect(document).to have_css("#operation-title", text: manual.operation.name)
    expect(document).to have_button("マニュアル確認済み", disabled: true)
    expect(document).to have_css(".operation-confirmation-level", text: "マニュアル確認済み")
  end

  it "AC-2: 今の版を確認済みなら無効で、版が上がると再度押せる" do
    skill.update!(level: 2, confirmed_version: 1)
    switch_to(staff)
    get staff_operations_path, params: { operation_id: manual.operation_id }
    expect(document).to have_button("マニュアル確認済み", disabled: true)

    manual.update!(version: 2)
    get staff_operations_path, params: { operation_id: manual.operation_id }
    expect(document).to have_button("マニュアルを確認した", disabled: false)

    expect { confirm }.not_to change(SkillLevelChange, :count)
    expect(skill.reload).to have_attributes(level: 2, confirmed_version: 2)
  end

  it "二度送信してもレベル変更の履歴は1件だけになる" do
    switch_to(staff)
    confirm

    expect { confirm }.not_to change(SkillLevelChange, :count)
  end

  it "AC-4: 管理者にはボタンを表示せず、直接送信しても拒否する" do
    [ admin_operations_path, staff_operations_path ].each do |path|
      get path, params: { operation_id: manual.operation_id }
      expect(document).to have_no_button("マニュアルを確認した")
    end

    expect { confirm }.not_to change(SkillLevelChange, :count)
    expect(response).to have_http_status(:forbidden)
    expect(skill.reload).to have_attributes(level: 0, confirmed_version: nil)
  end

  it "他人のID・レベル・確認版を送っても、本人と現在の版だけを更新する" do
    other_skill = create(:skill, operation: manual.operation)
    switch_to(staff)

    confirm(user_id: other_skill.user_id, skill_id: other_skill.id, level: 4, confirmed_version: 99)

    expect(skill.reload).to have_attributes(level: 1, confirmed_version: 1)
    expect(other_skill.reload).to have_attributes(level: 0, confirmed_version: nil)
  end

  it "確認後のHTMLにも管理者の見立てを含めない" do
    skill.update!(level: 3, admin_assessment: :needs_training)
    switch_to(staff)
    confirm
    follow_redirect!

    expect(response.body).not_to include("管理者の見立て", "▲", "▼", "▽", "◇",
      "admin_assessment", "can_train", "needs_training", "training_done", "backup_trainer")
    expect(skill.reload.admin_assessment).to eq("needs_training")
  end

  it "外部サイトのマニュアルも確認できる" do
    manual.update!(kind: :external, url: "https://example.com/manual", body: nil)
    switch_to(staff)
    confirm
    follow_redirect!

    expect(skill.reload).to have_attributes(level: 1, confirmed_version: 1)
    expect(document).to have_button("マニュアル確認済み", disabled: true)
  end

  it "表示後に改定された場合は保存せず、最新の手順を再表示する" do
    switch_to(staff)
    manual.update!(version: 2, body: "新しい手順")

    expect { confirm(version: 1) }.not_to change(SkillLevelChange, :count)

    follow_redirect!
    expect(skill.reload).to have_attributes(level: 0, confirmed_version: nil)
    expect(document).to have_text("新しい手順")
    expect(document).to have_text("マニュアルが更新されました。内容を確認して、もう一度押してください")
    expect(document).to have_button("マニュアルを確認した", disabled: false)
  end

  it "マニュアルがない作業への送信は404で、ボタンも表示しない" do
    operation = create(:operation)
    switch_to(staff)
    get staff_operations_path, params: { operation_id: operation.id }
    expect(document).to have_no_button("マニュアルを確認した")

    post staff_operation_confirmation_path(operation), params: { version: 1 }

    expect(response).to have_http_status(:not_found)
  end
end
