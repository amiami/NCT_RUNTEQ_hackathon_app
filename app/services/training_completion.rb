# 研修予定の「教え終わった」。予定を完了にし、教わった人を研修済みにする。1つのトランザクションで行い、
# どこかで保存できなければすべて元に戻す（errors に理由を入れて false を返す）。
#
# - 予定を done にし、done_on を今日にする
# - 教わる人がレベル0・1なら2にし、skill_level_changes に trained で記録する（changed_by は押した人）。2以上なら変えない
# - 教わる人の confirmed_version をマニュアルの今の版にする（研修でマニュアルの内容を教わったとみなす）
# - 教わる人の見立てが▼なら▽にし、付けた日時・付けた人を今の日時・押した人にする
#
# 押せるのはその予定の教える人だけ（管理者が担当の予定は管理者だけ）。管理者の画面（研修画面）と
# スタッフの画面（わたしのスキル）の両方から使うので、ここで確かめる
class TrainingCompletion
  TRAINED_LEVEL = 2

  attr_reader :errors

  def initialize(training:, by:)
    @training = training
    @by = by
    @errors = []
  end

  def save
    ApplicationRecord.transaction do
      # 2回押しがほぼ同時に届いても、2回目は完了済みとして止まるように、予定をロックして DB から読み直す。
      # ここで止まるときは、まだ何も書き換えていない
      @training.lock!
      return fail_with(I18n.t("training_completion.errors.already_done")) if @training.done?
      return fail_with(I18n.t("training_completion.errors.not_trainer")) unless trainer?

      @training.update!(status: :done, done_on: Date.current)
      train_trainee!
    end
    true
  rescue ActiveRecord::ActiveRecordError
    fail_with(I18n.t("training_completion.errors.not_saved"))
  end

  private

  def trainer?
    @by.present? && @training.trainer_id == @by.id
  end

  def train_trainee!
    skill = Skill.lock.find_by!(operation_id: @training.operation_id, user_id: @training.trainee_id)

    if skill.level < TRAINED_LEVEL
      SkillLevelChange.create!(skill:, changed_by: @by, from_level: skill.level, to_level: TRAINED_LEVEL, reason: :trained)
      skill.level = TRAINED_LEVEL
    end
    manual = @training.operation.manual
    skill.confirmed_version = manual.version if manual
    if skill.needs_training?
      skill.assign_attributes(admin_assessment: :training_done, admin_assessed_at: Time.current, admin_assessed_by: @by)
    end
    skill.save!
  end

  def fail_with(message)
    @errors = [ message ]
    false
  end
end
