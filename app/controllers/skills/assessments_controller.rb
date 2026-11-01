module Skills
  # 管理者の見立ての保存。管理者だけが使えるので、Admin::BaseController でスタッフを弾く
  class AssessmentsController < Admin::BaseController
    def update
      assessment_update = Skills::AssessmentUpdate.new(admin: current_user, assessments: assessments_params)

      if assessment_update.save
        redirect_to admin_skill_map_path, notice: t(".saved")
      else
        redirect_to admin_skill_map_path, alert: [ t(".failed"), *assessment_update.errors ]
      end
    end

    private

    # { スキルの ID => 見立て } の形。ID はマスごとに変わるので、キーを決めずに受け取る
    def assessments_params
      params.expect(assessments: {})
    end
  end
end
