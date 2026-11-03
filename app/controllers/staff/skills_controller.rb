module Staff
  # わたしのスキル（S-6）。左はわたしのスキルの一覧（#80）、右は教える予定・教わる予定（#63）
  class SkillsController < ApplicationController
    def index
      @teaching_trainings = []
      @learning_trainings = []
      return if current_user.nil?

      # わたしのスキルの一覧（左の欄）。部長はスキルを持たないので、スタッフのときだけ用意する
      @my_skill_list = MySkillList.for(current_user) if staff_operator?

      # 教える予定：自分が教える人の未完了の予定（相手が申告済みかの判定つき）
      @teaching_trainings = TrainingBoard.assigned_trainings(Training.where(trainer: current_user))
      @learning_trainings = Training.learning_for(current_user)
    end
  end
end
