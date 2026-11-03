require "rails_helper"

RSpec.describe "管理者の見立ての保存" do
  let!(:manager) { create(:user, :admin, name: "管理者") }
  let!(:yamamoto) { create(:user, name: "山本 直子") }
  let!(:with_senior) { create(:skill, user: yamamoto, level: 3) }
  let!(:on_own) { create(:skill, user: yamamoto, level: 4) }

  def save_assessments(assessments)
    patch skills_assessment_path, params: { assessments: }
  end

  context "管理者のとき" do
    it "まとめて保存し、スキルマップに戻って保存したことを表示する" do
      save_assessments(with_senior.id => "can_train", on_own.id => "backup_trainer")

      expect(response).to redirect_to(admin_skill_map_path)
      expect(with_senior.reload.admin_assessment).to eq "can_train"
      expect(on_own.reload.admin_assessment).to eq "backup_trainer"
      expect(with_senior.admin_assessed_by).to eq manager

      follow_redirect!
      expect(response.body).to include(I18n.t("skills.assessments.update.saved"))
    end

    it "付けられない組み合わせがあると、何も保存せず、スキルマップに戻って保存できなかったことを表示する" do
      save_assessments(with_senior.id => "can_train", on_own.id => "can_train")

      expect(response).to redirect_to(admin_skill_map_path)
      expect(with_senior.reload.admin_assessment).to be_nil
      expect(on_own.reload.admin_assessment).to be_nil

      follow_redirect!
      expect(response.body).to include(I18n.t("skills.assessments.update.failed"))
    end
  end

  context "AC-7: スタッフのとき" do
    before { patch operator_path, params: { user_id: yamamoto.id } }

    it "拒否されてスタッフの画面に戻され、見立ては変わらない" do
      save_assessments(with_senior.id => "can_train")

      expect(response).to redirect_to(staff_operations_path)
      expect(with_senior.reload.admin_assessment).to be_nil
      expect(with_senior.admin_assessed_at).to be_nil
    end
  end
end
