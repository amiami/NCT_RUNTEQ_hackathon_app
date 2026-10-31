class Skill < ApplicationRecord
  belongs_to :user
  belongs_to :operation
  belongs_to :admin_assessed_by, class_name: "User", optional: true
  has_many :skill_level_changes

  # 管理者の見立て。スタッフには見せない（HTML の属性・JSON・Turbo Stream にも出さない）。
  # 付けられるレベルは付けるときのサービスで確かめ、ここでは確かめない
  enum :admin_assessment, {
    can_train: 0,       # ▲ 研修権限
    needs_training: 1,  # ▼ 要研修
    training_done: 2,   # ▽ 研修済み
    backup_trainer: 3   # ◇ 教えるのは後回し
  }, validate: { allow_nil: true }

  validates :level, numericality: { only_integer: true, in: 0..4 }
  validates :operation_id, uniqueness: { scope: :user_id }
  validate :user_must_be_skill_holder

  # 前に確認した版より、マニュアルの版が上がっている（一度も確認していなければ false）
  def unread?
    manual = operation.manual
    confirmed_version.present? && manual.present? && confirmed_version < manual.version
  end

  private

  def user_must_be_skill_holder
    errors.add(:user, :not_skill_holder) if user&.admin?
  end
end
