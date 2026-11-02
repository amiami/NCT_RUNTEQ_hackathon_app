module Trainings
  # 研修予定の「教え終わった」。部長（研修画面の「指示済みの研修」）とスタッフ（わたしのスキル）の両方から使う。
  # 押せるのはその予定の教える人だけで、TrainingCompletion で確かめる
  class CompletionsController < ApplicationController
    def create
      training = Training.find(params[:training_id])
      completion = TrainingCompletion.new(training:, by: current_user)

      if completion.save
        redirect_back_or_to default_return_path, notice: t("training_completion.done"), status: :see_other
      else
        redirect_back_or_to default_return_path, alert: completion.errors, status: :see_other
      end
    end

    private

    # 押した画面に戻る。戻り先が分からないときは、部長は研修画面、スタッフはわたしのスキル
    def default_return_path
      staff_operator? ? staff_skills_path : admin_trainings_path
    end
  end
end
