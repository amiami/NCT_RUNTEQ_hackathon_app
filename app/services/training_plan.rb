# 研修画面（S-3）の「変更を保存」。下書きの予定の追加・取り消し・期限の変更を、1つのトランザクションでまとめて反映する。
# 1件でも保存できないものがあれば、すべて反映しない（errors に理由を入れて false を返す）。
#
# 反映する順番は 取り消し → 追加 → 期限の変更。
# - 取り消しを先にするのは、同じ人の予定を取り消して別の教える人で頼み直すことを1回でできるようにするため
# - 期限を最後にするのは、その回で追加した予定にも同じ期限をそろえるため
class TrainingPlan
  attr_reader :errors

  # additions:     [{ operation_id:, trainer_id:, trainee_id:, due_on: }]（教わる人1人につき1件）
  # cancellations: [training_id, …]
  # due_dates:     [{ operation_id:, due_on: }]（due_on が空なら期限を消す）
  def initialize(additions: [], cancellations: [], due_dates: [])
    @additions = additions.map { |attributes| attributes.to_h.symbolize_keys }
    @cancellations = cancellations
    @due_dates = due_dates.map { |attributes| attributes.to_h.symbolize_keys }
    @errors = []
  end

  def save
    ApplicationRecord.transaction do
      cancel_trainings!
      add_trainings!
      change_due_dates!
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    fail_with(message_for(e.record))
  rescue ActiveRecord::RecordNotFound
    fail_with(I18n.t("training_plan.errors.not_found"))
  rescue ActiveRecord::RecordNotUnique
    # 2回押しがほぼ同時に届き、どちらもバリデーションを通ったときは、部分ユニークインデックスが防ぐ
    fail_with(I18n.t("training_plan.errors.duplicated"))
  rescue Date::Error
    fail_with(I18n.t("training_plan.errors.invalid_due_on"))
  end

  private

  # 完了した予定は、モデルの before_destroy で削除できない（RecordNotDestroyed）
  def cancel_trainings!
    @cancellations.each { |id| Training.find(id).destroy! }
  end

  # 教える人・教わる人の条件は、Training の作成時のチェック（Skill.trainer_candidates・Skill.training_targets）で確かめる。
  # 教える人が管理者なら、モデルのコールバックで acknowledged になる
  def add_trainings!
    @additions.each do |attributes|
      Training.create!(
        operation_id: attributes[:operation_id], trainer_id: attributes[:trainer_id],
        trainee_id: attributes[:trainee_id], due_on: parse_date(attributes[:due_on])
      )
    end
  end

  # 期限は作業ごと。その作業の未完了の予定すべてを同じ期限にする。予定がない作業は対象の行がないので何も保存しない
  def change_due_dates!
    @due_dates.each do |attributes|
      Training.unfinished.where(operation_id: attributes[:operation_id])
              .update_all(due_on: parse_date(attributes[:due_on]), updated_at: Time.current)
    end
  end

  def parse_date(value)
    value.presence && Date.iso8601(value.to_s)
  end

  # どの予定で保存できなかったか分かるよう、作業と教わる人の名前を前に付ける
  def message_for(training)
    label = [ training.operation&.name, training.trainee&.name ]
    prefix = label.all?(&:present?) ? "#{label[0]}（#{label[1]}）：" : ""
    "#{prefix}#{training.errors.full_messages.to_sentence}"
  end

  def fail_with(message)
    @errors = [ message ]
    false
  end
end
