require "rails_helper"

RSpec.describe "研修予定の「教え終わった」" do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let(:yoshida) { create(:user, name: "吉田", sort_order: 2) }
  let(:kato) { create(:user, name: "加藤", sort_order: 3) }
  let(:payroll) { create(:operation, name: "給与計算") }

  before do
    travel_to(Time.zone.local(2026, 11, 2, 10, 30))
    create(:manual, operation: payroll, version: 2)
    create(:skill, operation: payroll, user: yamamoto, level: 4)
    create(:skill, operation: payroll, user: yoshida, level: 3, admin_assessment: :needs_training, confirmed_version: 1)
    create(:skill, operation: payroll, user: kato, level: 0)
  end

  def operate_as(user)
    patch operator_path, params: { user_id: user&.id }
  end

  def flash_text
    Capybara.string(response.body).find_by_id("flash-messages").text
  end

  describe "部長が担当の予定（AC-7）" do
    let(:training) { create(:training, operation: payroll, trainer: admin, trainee: kato) }

    it "部長が完了にでき、研修画面に戻って完了したことが出る" do
      post training_completion_path(training)

      expect(response).to redirect_to(admin_trainings_path)
      expect(training.reload).to be_done
      expect(Skill.find_by!(operation: payroll, user: kato).level).to eq 2

      follow_redirect!
      expect(flash_text).to include("「教え終わった」にしました")
    end
  end

  describe "スタッフが教える人の予定" do
    let(:training) { create(:training, operation: payroll, trainer: yamamoto, trainee: yoshida) }

    it "教える人のスタッフが完了にでき、わたしのスキルに戻る" do
      operate_as(yamamoto)

      post training_completion_path(training)

      expect(response).to redirect_to(staff_skills_path)
      expect(training.reload).to be_done
    end

    it "戻ったスタッフの画面の HTML に、管理者の見立て（▽など）を含めない" do
      operate_as(yamamoto)

      post training_completion_path(training)
      follow_redirect!

      expect(Skill.find_by!(operation: payroll, user: yoshida)).to be_training_done
      expect(response.body).not_to include("training_done", "needs_training", "管理者の見立て", "▽", "▼")
    end

    it "教える人ではないスタッフが送ると、何も変わらず理由が出る（AC-6）" do
      operate_as(kato)

      post training_completion_path(training)

      expect(response).to redirect_to(staff_skills_path)
      expect(training.reload).not_to be_done
      follow_redirect!
      expect(flash_text).to include("この研修予定の教える人だけが「教え終わった」にできます")
    end

    it "部長が送っても、スタッフが担当の予定は完了にならない（AC-6）" do
      post training_completion_path(training)

      expect(response).to redirect_to(admin_trainings_path)
      expect(training.reload).not_to be_done
    end

    it "完了した予定を送ると、何も変わらず理由が出る（AC-5）" do
      operate_as(yamamoto)
      post training_completion_path(training)

      expect { post training_completion_path(training) }.not_to change(SkillLevelChange, :count)
      follow_redirect!
      expect(flash_text).to include("この研修予定はすでに完了しています")
    end
  end

  it "存在しない予定を送ると、404 になる" do
    post training_completion_path(training_id: 0)

    expect(response).to have_http_status(:not_found)
  end
end
