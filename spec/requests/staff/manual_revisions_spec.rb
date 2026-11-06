require "rails_helper"

RSpec.describe "スタッフの改訂のお知らせ" do
  let!(:staff) { create(:user) }
  let!(:manager) { create(:user, :admin) }

  before { patch operator_path, params: { user_id: staff.id } }

  it "改訂を新しい順に表示し、再確認とマニュアルへのリンクを出す" do
    manual = create(:manual, version: 3)
    create(:skill, user: staff, operation: manual.operation, level: 1, confirmed_version: 1)
    create(:manual_revision, manual:, user: manager, version: 2, memo: "以前の変更", created_at: 2.days.ago)
    create(:manual_revision, manual:, user: manager, version: 3, memo: "今回の変更", created_at: 1.day.ago)
    get staff_manual_revisions_path
    document = Capybara.string(response.body)
    expect(document.all("tbody tr").map(&:text)).to match([ /今回の変更/, /以前の変更/ ])
    expect(document).to have_css("tbody tr", text: "再確認", count: 2)
    expect(document).to have_link("マニュアルを見る", href: staff_operations_path(operation_id: manual.operation_id), count: 2)
  end

  it "一度も確認していない人には再確認を出さない" do
    manual = create(:manual, version: 2)
    create(:skill, user: staff, operation: manual.operation, level: 0)
    create(:manual_revision, manual:, user: manager, version: 2)
    get staff_manual_revisions_path
    expect(Capybara.string(response.body)).to have_no_css("tbody .operation-badge-revision")
  end

  it "改訂がないときは空の案内を出す" do
    get staff_manual_revisions_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("改訂のお知らせはありません")
  end

  it "確認済みにすると再確認が消える" do
    manual = create(:manual, version: 2)
    create(:skill, user: staff, operation: manual.operation, level: 1, confirmed_version: 1)
    create(:manual_revision, manual:, user: manager, version: 2)
    post staff_operation_confirmation_path(manual.operation), params: { version: 2 }
    get staff_manual_revisions_path
    expect(Capybara.string(response.body)).to have_no_css("tbody .operation-badge-revision")
  end

  def sql_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end

  def add_revision
    manual = create(:manual, version: 2)
    create(:skill, user: staff, operation: manual.operation, level: 1, confirmed_version: 1)
    create(:manual_revision, manual:, user: manager, version: 2)
  end

  it "作業と改訂が増えても問い合わせの回数が増えない" do
    add_revision
    before_count = sql_count { get staff_manual_revisions_path }
    3.times { add_revision }
    after_count = sql_count { get staff_manual_revisions_path }
    expect(after_count).to eq(before_count)
  end
end
