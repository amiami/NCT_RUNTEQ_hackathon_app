require "rails_helper"

RSpec.describe "作業ごとのスタッフ状況" do
  let!(:manager) { create(:user, :admin, name: "管理者") }
  let!(:manual) { create(:manual, version: 2) }
  let(:operation) { manual.operation }

  def show_status
    get admin_operations_path, params: { operation_id: operation.id }
  end

  def panel
    Capybara.string(response.body).find("section[aria-labelledby='operation-staff-status-title']")
  end

  def row(name)
    panel.find("li", text: name)
  end

  it "スタッフ全員を表示順に並べ、スキル未作成もレベル0・未確認・研修まだで表示する" do
    create(:user, name: "後の人", sort_order: 2)
    create(:user, name: "先の人", sort_order: 1)
    show_status
    expect(panel.all("li").map(&:text)).to match([ /先の人/, /後の人/ ])
    expect(row("先の人")).to have_text("未確認")
    expect(row("先の人")).to have_css(".skill-level", exact_text: "レベル0")
    expect(row("先の人")).to have_text("研修：まだ")
    expect(panel).to have_no_text("管理者")
  end

  it "レベル0〜4と確認状況3種類を表示し、見立ての属性や値を含めない" do
    (0..4).each do |level|
      user = create(:user, name: "スタッフ#{level}")
      create(:skill, user: user, operation: operation, level: level,
        confirmed_version: [ nil, 1, 2, 2, 2 ][level],
        admin_assessment: level == 3 ? :needs_training : nil)
    end
    show_status
    (0..4).each { |level| expect(row("スタッフ#{level}")).to have_css(".skill-level", exact_text: "レベル#{level}") }
    expect(row("スタッフ0")).to have_text("未確認")
    expect(row("スタッフ1")).to have_text("改定後 未確認")
    expect(row("スタッフ2")).to have_text("確認済み")
    expect(row("スタッフ3")).to have_text("研修：なし（自分で習得）")
    expect(row("スタッフ4")).to have_text("研修：なし（自分で習得）")
    expect(panel.native.to_html).not_to match(/admin_assessment|needs_training|can_train|training_done|backup_trainer|▲|▼|▽|◇/)
  end

  it "完了済み研修のうち最新の日付・教えた人を表示し、未完了予定は使わない" do
    trainee = create(:user, name: "教わった人")
    create(:skill, user: trainee, operation: operation, level: 0)
    old_trainer = create(:user, :admin, name: "以前の先生")
    create(:training, operation: operation, trainee: trainee, trainer: old_trainer, status: :done, done_on: Date.new(2026, 9, 1))
    create(:training, operation: operation, trainee: trainee, trainer: manager, status: :done, done_on: Date.new(2026, 10, 2))
    create(:training, operation: operation, trainee: trainee, trainer: old_trainer)
    show_status
    expect(row("教わった人")).to have_text("研修：済み（管理者から・2026/10/02）")
    expect(row("教わった人")).to have_no_text("以前の先生")
    expect(row("教わった人")).to have_no_text("研修：まだ")
  end

  it "スタッフが教えた研修にはさんを付ける" do
    trainer = create(:user, name: "教えた人")
    trainee = create(:user, name: "教わった人")
    create(:skill, user: trainer, operation: operation, level: 4)
    create(:skill, user: trainee, operation: operation, level: 0)
    create(:training, operation: operation, trainee: trainee, trainer: trainer,
      status: :done, done_on: Date.new(2026, 10, 2))
    show_status
    expect(row("教わった人")).to have_text("研修：済み（教えた人さんから・2026/10/02）")
  end

  it "別の作業のスキルや研修を混ぜず、選択した作業で切り替わる" do
    other_manual = create(:manual)
    trainee = create(:user, name: "対象者")
    create(:skill, user: trainee, operation: operation, level: 4, confirmed_version: 2)
    create(:skill, user: trainee, operation: other_manual.operation, level: 0)
    create(:training, operation: other_manual.operation, trainee: trainee, trainer: manager, status: :done, done_on: Date.new(2026, 10, 2))
    show_status
    expect(row("対象者")).to have_text("確認済み")
    expect(row("対象者")).to have_text("研修：なし（自分で習得）")
    get admin_operations_path, params: { operation_id: other_manual.operation_id }
    expect(row("対象者")).to have_css(".skill-level", exact_text: "レベル0")
    expect(row("対象者")).to have_text("未確認")
    expect(row("対象者")).to have_text("研修：済み")
  end

  it "スタッフ画面にはカードも他人の情報も出さない" do
    staff = create(:user)
    create(:user, name: "表示されてはいけない人")
    patch operator_path, params: { user_id: staff.id }
    get staff_operations_path, params: { operation_id: operation.id }
    expect(Capybara.string(response.body).find("main").native.to_html).not_to include("operation-staff-status", "表示されてはいけない人")
  end

  it "スタッフがいなければ空の案内を出す" do
    show_status
    expect(panel).to have_text("スタッフが登録されていません")
  end

  it "マニュアル未登録でもスタッフ状況を表示できる" do
    create(:user, name: "対象者")
    get admin_operations_path, params: { operation_id: create(:operation).id }
    expect(row("対象者")).to have_text("未確認")
  end
end
