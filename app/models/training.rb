class Training < ApplicationRecord
  belongs_to :operation
  belongs_to :trainer, class_name: "User"
  belongs_to :trainee, class_name: "User"

  # 数字は部分ユニークインデックス index_trainings_open_per_trainee の条件（status <> 2）と合わせる
  enum :status, { requested: 0, acknowledged: 1, done: 2 }, validate: true

  validates :trainee_id, uniqueness: { scope: :operation_id, conditions: -> { where.not(status: :done) } },
                         unless: :done?
  validate :trainee_must_differ_from_trainer
  # 作成後に教える人・教わる人のレベルや見立てが変わっても、予定は続けるので作成時だけ確かめる
  validate :trainer_must_be_candidate, on: :create
  validate :trainee_must_be_candidate, on: :create

  private

  def trainee_must_differ_from_trainer
    errors.add(:trainee, :same_as_trainer) if trainee_id.present? && trainee_id == trainer_id
  end

  # 教える人：その作業でレベル4（▼を除く）か、レベル3で▲、または管理者（どの作業でも）
  def trainer_must_be_candidate
    return if trainer.nil? || trainer.admin?

    skill = skill_of(trainer)
    candidate = skill.present? &&
                ((skill.level == 4 && !skill.needs_training?) || (skill.level == 3 && skill.can_train?))
    errors.add(:trainer, :not_trainer_candidate) unless candidate
  end

  # 教わる人：その作業でレベル0・1か、▼（4▼も含む）
  def trainee_must_be_candidate
    return if trainee.nil?

    skill = skill_of(trainee)
    candidate = skill.present? && (skill.level <= 1 || skill.needs_training?)
    errors.add(:trainee, :not_trainee_candidate) unless candidate
  end

  def skill_of(user)
    Skill.find_by(user:, operation:)
  end
end
