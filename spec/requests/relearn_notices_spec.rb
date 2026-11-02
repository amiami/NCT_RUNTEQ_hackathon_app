require "rails_helper"

RSpec.describe "改定後の「再確認」と「改定されました」（作業マニュアル・スタッフ）" do
  let!(:manager) { create(:user, :admin) }
  let!(:staff) { create(:user) }
  # 第1版を確認したあと、第2版に改定された作業
  let!(:revised_manual) { create(:manual, version: 2) }
  # 最新の版を確認済みの作業
  let!(:latest_manual) { create(:manual, version: 2) }
  let!(:revised_skill) do
    create(:skill, user: staff, operation: revised_manual.operation, level: 3, confirmed_version: 1,
      admin_assessment: :needs_training, admin_assessed_by: manager, admin_assessed_at: Time.current)
  end

  before { create(:skill, user: staff, operation: latest_manual.operation, level: 2, confirmed_version: 2) }

  def document
    Capybara.string(response.body)
  end

  def switch_to(user)
    patch operator_path, params: { user_id: user.id }
  end

  def tree_link(operation)
    document.find("main a[href$='operation_id=#{operation.id}']")
  end

  def show(manual)
    get staff_operations_path, params: { operation_id: manual.operation_id }
  end

  def sql_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end

  it "AC-1: 改定前に確認していた作業にだけ、ツリーで「再確認」が出る" do
    switch_to(staff)
    show(latest_manual)

    expect(tree_link(revised_manual.operation)).to have_css(".operation-badge", text: "再確認")
    expect(tree_link(latest_manual.operation)).to have_no_text("再確認")
  end

  it "AC-2・3: 一度も確認していない人には、版が上がっていても「再確認」も注意も出ない" do
    revised_skill.update!(level: 0, confirmed_version: nil, admin_assessment: nil)
    switch_to(staff)
    show(revised_manual)

    expect(tree_link(revised_manual.operation)).to have_no_text("再確認")
    expect(document).to have_no_text("このマニュアルは改定されました")
  end

  it "AC-3: 「再確認」の人がその作業を開くと、手順の上に注意が出る" do
    switch_to(staff)
    show(revised_manual)

    expect(document).to have_css(".operation-revised-alert", text: "このマニュアルは改定されました")
    expect(document).to have_css(".operation-revised-alert ~ .operation-manual-steps")
  end

  it "AC-3: 最新の版を確認済みの作業には注意が出ない" do
    switch_to(staff)
    show(latest_manual)

    expect(document).to have_no_text("このマニュアルは改定されました")
  end

  it "AC-4: 「マニュアルを確認した」を押すと、「再確認」と注意の両方が消える" do
    switch_to(staff)
    post staff_operation_confirmation_path(revised_manual.operation), params: { version: 2 }
    follow_redirect!

    expect(revised_skill.reload.confirmed_version).to eq(2)
    expect(tree_link(revised_manual.operation)).to have_no_text("再確認")
    expect(document).to have_no_text("このマニュアルは改定されました")
  end

  it "AC-5: 管理者が改定しても、レベル・見立て・確認した版は変わらず、スタッフに「再確認」が出る" do
    revised_skill.update!(confirmed_version: 2)
    revised_manual.update!(version: 2)
    patch admin_operation_manual_path(revised_manual.operation),
      params: { manual: { body: "新しい手順", memo: "書類を変更", version: 2 } }

    expect(revised_manual.reload.version).to eq(3)
    expect(revised_skill.reload).to have_attributes(level: 3, confirmed_version: 2, admin_assessment: "needs_training")

    switch_to(staff)
    show(revised_manual)
    expect(tree_link(revised_manual.operation)).to have_css(".operation-badge", text: "再確認")
    expect(document).to have_text("このマニュアルは改定されました")
  end

  it "AC-6: 管理者の作業ツリーと、管理者が開いたスタッフ画面には出ない" do
    [ admin_operations_path, staff_operations_path ].each do |path|
      get path, params: { operation_id: revised_manual.operation_id }

      expect(document).to have_no_text("再確認")
      expect(document).to have_no_text("このマニュアルは改定されました")
    end
  end

  it "AC-6: 「再確認」の人の画面にも、管理者の見立てを表す値を含めない" do
    switch_to(staff)
    show(revised_manual)

    expect(document).to have_text("再確認")
    expect(response.body).not_to include("管理者の見立て", "▲", "▼", "▽", "◇",
      "admin_assessment", "can_train", "needs_training", "training_done", "backup_trainer")
  end

  it "作業が増えても、問い合わせの回数は変わらない（N+1 にならない）" do
    switch_to(staff)
    before_count = sql_count { show(revised_manual) }

    3.times do
      manual = create(:manual, version: 2)
      create(:skill, user: staff, operation: manual.operation, confirmed_version: 1)
    end
    after_count = sql_count { show(revised_manual) }

    expect(after_count).to eq(before_count)
  end
end
