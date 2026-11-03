require "rails_helper"

RSpec.describe "改訂履歴の一覧（管理者）" do
  let!(:manager) { create(:user, :admin) }
  let!(:paid_leave) do
    create(:manual, operation: create(:operation, name: "有給休暇の管理"), version: 2, body: "新しい手順")
  end
  let!(:payroll) { create(:manual, :external, operation: create(:operation, name: "給与計算"), version: 3) }

  before do
    travel_to Time.zone.local(2026, 11, 3, 10)
    # わざと古い順に作らず、並び順を画面で確かめる
    create(:manual_revision, manual: payroll, user: manager, version: 2, memo: "様式が変わった",
      created_at: Time.utc(2026, 10, 1, 3))
    # 日本時間では 10/20 00:30（UTC のままだと 10/19 になる）
    create(:manual_revision, manual: paid_leave, user: manager, version: 2, memo: nil,
      body_before: "古い手順の本文", body_after: "新しい手順の本文", created_at: Time.utc(2026, 10, 19, 15, 30))
    create(:manual_revision, manual: payroll, user: manager, version: 3, memo: "",
      created_at: Time.utc(2026, 10, 25, 1))
  end

  def document
    Capybara.string(response.body)
  end

  def rows
    document.all("main tbody tr")
  end

  def sql_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end

  it "AC-1: 日付（日本時間）・作業と版・変更内容が、新しい順に並ぶ" do
    get admin_manual_revisions_path

    expect(response).to have_http_status(:ok)
    expect(document.all("main thead th").map(&:text)).to include("日付", "作業", "種類", "変更内容")
    expect(rows.size).to eq(3)
    expect(rows[0]).to have_text("2026/10/25").and have_text("給与計算").and have_text("第3版")
    expect(rows[1]).to have_text("2026/10/20").and have_text("有給休暇の管理").and have_text("第2版")
    expect(rows[2]).to have_text("2026/10/01").and have_text("給与計算").and have_text("第2版")
    expect(rows[2]).to have_text("様式が変わった")
  end

  it "AC-2: 種類が「アプリ内」「外部サイト」で区別して表示される" do
    get admin_manual_revisions_path

    expect(rows[0]).to have_text("外部サイト")
    expect(rows[1]).to have_text("アプリ内")
    expect(rows[1]).to have_no_text("外部サイト")
  end

  it "メモが空（nil・空文字）なら「（メモなし）」と表示する" do
    get admin_manual_revisions_path

    expect(rows[0]).to have_text("（メモなし）")
    expect(rows[1]).to have_text("（メモなし）")
    expect(rows[2]).to have_no_text("（メモなし）")
  end

  it "変更前・変更後の手順（body_before・body_after）は画面に出さない" do
    get admin_manual_revisions_path

    expect(response.body).not_to include("古い手順の本文", "新しい手順の本文")
  end

  it "AC-3: 「マニュアルを見る」を押すと、管理者の作業ツリーのその作業のマニュアルに移る" do
    get admin_manual_revisions_path
    href = rows[1].find_link("マニュアルを見る")[:href]
    expect(href).to eq(admin_operations_path(operation_id: paid_leave.operation_id))

    get href
    expect(document.find("main a[href$='operation_id=#{paid_leave.operation_id}']")[:"aria-current"]).to eq("page")
    expect(document).to have_css("#operation-title", text: "有給休暇の管理")
  end

  it "AC-4: スタッフが URL を開くと、スタッフの画面に戻される" do
    patch operator_path, params: { user_id: create(:user).id }
    get admin_manual_revisions_path

    expect(response).to redirect_to(staff_operations_path)
  end

  it "AC-5: 改訂がまだないときも、崩れずに案内を表示する" do
    ManualRevision.delete_all
    get admin_manual_revisions_path

    expect(response).to have_http_status(:ok)
    expect(document).to have_text("改訂はまだありません")
    expect(document).to have_no_css("main table")
  end

  it "改訂が増えても、問い合わせの回数は変わらない（N+1 にならない）" do
    before_count = sql_count { get admin_manual_revisions_path }

    3.times do
      manual = create(:manual, version: 2)
      create(:manual_revision, manual:, user: manager, version: 2)
    end
    after_count = sql_count { get admin_manual_revisions_path }

    expect(rows.size).to eq(6)
    expect(after_count).to eq(before_count)
  end
end
