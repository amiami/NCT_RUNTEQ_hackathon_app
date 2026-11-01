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

  # できる人。スキルを持つ人のうちレベル4（◇・▼の人も含む）
  scope :capable, -> { where(level: 4).joins(:user).merge(User.skill_holders) }

  # 教える人の候補。研修画面の一覧と Training の作成時のチェックで共通に使う。
  # レベル4（▼以外）か、レベル3で▲。▲・▽はレベル4では表示しないが、値は残るので候補に入る（NULL も含める）
  scope :trainer_candidates, lambda {
    where(level: 4, admin_assessment: [ nil, :can_train, :training_done, :backup_trainer ])
      .or(where(level: 3, admin_assessment: :can_train))
      .joins(:user).merge(User.skill_holders)
      .order(Arel.sql(sanitize_sql_array([ <<~SQL.squish, admin_assessments[:backup_trainer] ])), "users.sort_order", "users.id")
        CASE
          WHEN skills.level = 3 THEN 1
          WHEN skills.admin_assessment = ? THEN 2
          ELSE 0
        END
      SQL
  }

  # 研修の対象（教わる人になりうる人）。レベル0・1と▼（4▼も含む）。
  # 研修画面に出す作業・カードの状態・教わる人の候補、Training の作成時のチェックで共通に使う
  scope :training_targets, lambda {
    where(level: 0..1).or(where(admin_assessment: :needs_training))
      .joins(:user).merge(User.skill_holders)
      .order("users.sort_order", "users.id")
  }

  # 作業ごとのできる人の数を1回のクエリで返す（{ operation_id => 人数 }）。
  # できる人がいない作業は含まないので、使う側で fetch(id, 0) にする
  def self.capable_counts
    capable.group(:operation_id).count
  end

  # 今のレベルで意味のある見立てか。管理者画面ではこれが true の見立てだけ表示する。
  # レベル3は▲・▼・▽、レベル4は▼・◇。それ以外（4▲・4▽・3◇など）は値を残したまま表示しない
  MEANINGFUL_ASSESSMENTS = {
    3 => %w[can_train needs_training training_done],
    4 => %w[needs_training backup_trainer]
  }.freeze

  def assessment_meaningful?
    MEANINGFUL_ASSESSMENTS.fetch(level, []).include?(admin_assessment)
  end

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
