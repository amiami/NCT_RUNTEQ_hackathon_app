class Training < ApplicationRecord
  belongs_to :operation
  belongs_to :trainer, class_name: "User"
  belongs_to :trainee, class_name: "User"

  # 数字は部分ユニークインデックス index_trainings_open_per_trainee の条件（status <> 2）と合わせる
  enum :status, { requested: 0, acknowledged: 1, done: 2 }, validate: true

  # 完了していない予定（教える人の未確認・確認済み）
  scope :unfinished, -> { where.not(status: :done) }
  # その人が教える人か教わる人の予定（わたしのスキルの「教える予定」「教わる予定」）。
  # 教える人と教わる人は別の人（バリデーション）なので、同じ予定を二重に数えることはない
  scope :involving, ->(user) { where(trainer: user).or(where(trainee: user)) }
  # 研修済み（誰から・いつ）。作業×教わる人ごとに、done の予定のうち done_on が最新の1件。
  # 1組なら find_by(operation:, trainee:)、一覧なら includes(:trainer) を付けて index_by で引く。
  # 最新の id を選ぶ部分（PostgreSQL の DISTINCT ON）は中に閉じ込め、外側では count や並べ替えも使えるようにする
  scope :latest_done, lambda {
    latest_ids = done.select("DISTINCT ON (trainings.operation_id, trainings.trainee_id) trainings.id")
                     .order(:operation_id, :trainee_id, done_on: :desc, id: :desc)
    where(id: latest_ids)
  }

  validates :trainee_id, uniqueness: { scope: :operation_id, conditions: -> { where.not(status: :done) } },
                         unless: :done?
  validate :trainee_must_differ_from_trainer
  # 作成後に教える人・教わる人のレベルや見立てが変わっても、予定は続けるので作成時だけ確かめる
  validate :trainer_must_be_candidate, on: :create
  validate :trainee_must_be_candidate, on: :create

  # 管理者自身が頼んだ予定なので、教える人の確認（通知の帯）はいらない
  before_create :acknowledge, if: -> { requested? && trainer.admin? }
  # 完了した予定は研修済み（誰から・いつ）の記録なので消さない
  before_destroy :prevent_destroying_done

  private

  def acknowledge
    self.status = :acknowledged
  end

  def prevent_destroying_done
    return unless done?

    errors.add(:base, :cannot_destroy_done)
    throw :abort
  end

  def trainee_must_differ_from_trainer
    errors.add(:trainee, :same_as_trainer) if trainee_id.present? && trainee_id == trainer_id
  end

  # 教える人：Skill.trainer_candidates に入る人、または管理者（Skill を持たないが、どの作業でも教えられる）
  def trainer_must_be_candidate
    return if trainer.nil? || trainer.admin?

    candidate = Skill.trainer_candidates.exists?(user: trainer, operation:)
    errors.add(:trainer, :not_trainer_candidate) unless candidate
  end

  # 教わる人：Skill.training_targets に入る人
  def trainee_must_be_candidate
    return if trainee.nil?

    candidate = Skill.training_targets.exists?(user: trainee, operation:)
    errors.add(:trainee, :not_trainee_candidate) unless candidate
  end
end
