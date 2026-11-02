module Admin
  # 研修画面（S-3）の「変更を保存」。下書きの予定の追加・取り消し・期限の変更を TrainingPlan でまとめて反映する。
  # 管理者だけが使える（スタッフのときは Admin::BaseController がスタッフの画面に戻す）
  class TrainingPlansController < Admin::BaseController
    def update
      plan = TrainingPlan.new(**training_plan_params)

      if plan.save
        redirect_to admin_trainings_path, notice: t("training_plan.saved"), status: :see_other
      else
        flash.now[:alert] = [ t("training_plan.not_saved"), *plan.errors ]
        respond_to do |format|
          # 画面を作り直さず、フラッシュの枠だけ差し替えて、画面の下書きを残す
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash"),
                   status: :unprocessable_content
          end
          format.html { redirect_to admin_trainings_path, alert: flash.now[:alert], status: :see_other }
        end
      end
    end

    private

    def training_plan_params
      permitted = params.fetch(:training_plan, {}).permit(
        additions: %i[operation_id trainer_id trainee_id due_on],
        cancellations: [],
        due_dates: %i[operation_id due_on]
      )
      {
        additions: permitted.fetch(:additions, []).map(&:to_h),
        cancellations: permitted.fetch(:cancellations, []),
        due_dates: permitted.fetch(:due_dates, []).map(&:to_h)
      }
    end
  end
end
