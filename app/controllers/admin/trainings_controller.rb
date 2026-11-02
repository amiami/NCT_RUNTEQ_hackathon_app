module Admin
  # 研修画面（S-3）。左に作業ごとのカード、右に指示済みの研修を出す。
  # 並び順は開いた時点で決まり、絞り込みは画面の中（Stimulus）で切り替える（#61 の下書きを消さないため）
  class TrainingsController < Admin::BaseController
    def index
      @cards = TrainingBoard.cards
      @assigned_trainings = TrainingBoard.assigned_trainings
    end
  end
end
