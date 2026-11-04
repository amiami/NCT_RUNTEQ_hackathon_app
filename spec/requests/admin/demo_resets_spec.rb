require "rails_helper"

RSpec.describe "デモ用データのリセット" do
  before do
    create(:user, :admin)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DEMO_RESET_ENABLED").and_return("true")
  end

  it "管理者に確認つきのボタンを表示する" do
    get admin_operations_path
    expect(response.body).to include("デモ用データに戻す", "data-turbo-confirm")
  end

  it "無効ならボタンを出さず、直接の操作も404にする" do
    allow(ENV).to receive(:[]).with("DEMO_RESET_ENABLED").and_return(nil)
    get admin_operations_path
    expect(response.body).not_to include("デモ用データに戻す")
    post admin_demo_reset_path
    expect(response).to have_http_status(:not_found)
  end

  it "スタッフからは受け付けない" do
    staff = create(:user)
    patch operator_path, params: { user_id: staff.id }
    expect { post admin_demo_reset_path }.not_to change(User, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "全データを初期状態に戻し、管理者のトップへ移る" do
    create(:operation, name: "追加した作業")
    post admin_demo_reset_path
    expect(response).to redirect_to(root_path)
    expect(Operation.exists?(name: "追加した作業")).to be false
    expect([ User.count, Operation.count, Skill.count, Training.done.count ]).to eq([ 6, 13, 65, 7 ])
    follow_redirect!
    expect(response).to redirect_to(admin_operations_path)
  end

  it "投入に失敗したら削除も巻き戻す" do
    original = User.order(:id).pluck(:id, :name)
    allow(Rails.application).to receive(:load_seed).and_raise(ActiveRecord::RecordInvalid)
    expect { DemoReset.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(User.order(:id).pluck(:id, :name)).to eq(original)
  end
end
