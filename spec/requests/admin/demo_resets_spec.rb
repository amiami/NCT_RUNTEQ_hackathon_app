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

  it "変更した記録を初期状態に戻し、管理者のトップへ移る" do
    Rails.application.load_seed
    skill = Skill.find_by!(user: User.find_by!(name: "吉田 あかり"), operation: Operation.find_by!(name: "給与計算"))
    SelfDeclaration.call(user: skill.user, operation: skill.operation, level: 3)
    skill.update!(admin_assessment: :needs_training, confirmed_version: nil)
    skill.operation.manual.update!(body: "変更済み", version: 2)
    create(:manual_revision, manual: skill.operation.manual, user: User.find_by!(admin: true), version: 2)
    create(:training, operation: skill.operation, trainee: skill.user, trainer: User.find_by!(admin: true))
    create(:operation, name: "追加した作業")
    post admin_demo_reset_path
    expect(response).to redirect_to(root_path)
    expect(Operation.exists?(name: "追加した作業")).to be false
    restored = Skill.find_by!(user: User.find_by!(name: "吉田 あかり"), operation: Operation.find_by!(name: "給与計算"))
    expect(restored).to have_attributes(level: 1, admin_assessment: nil, confirmed_version: 1)
    expect([ ManualRevision.count, Training.unfinished.count, SkillLevelChange.count ]).to eq([ 3, 0, 0 ])
    follow_redirect!
    expect(response).to redirect_to(admin_operations_path)
  end

  it "投入に失敗したら削除も巻き戻す" do
    Rails.application.load_seed
    models = [ User, Category, Operation, Manual, ManualRevision, Skill, Training, SkillLevelChange ]
    original = models.map { |model| model.order(:id).map(&:attributes) }
    allow(Rails.application).to receive(:load_seed).and_raise(ActiveRecord::RecordInvalid)
    expect { DemoReset.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(models.map { |model| model.order(:id).map(&:attributes) }).to eq(original)
  end
end
