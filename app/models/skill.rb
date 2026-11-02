class Skill < ApplicationRecord
  belongs_to :user
  belongs_to :operation
  belongs_to :admin_assessed_by, class_name: "User", optional: true
  has_many :skill_level_changes

  # 今のレベルで意味のある見立て（#assessment_meaningful? で使う）。管理者画面ではこれに入る見立てだけ表示する。
  # レベル3は▲・▼・▽、レベル4は▼・◇。それ以外（4▲・4▽・3◇など）は値を残したまま表示しない
  MEANINGFUL_ASSESSMENTS = {
    3 => %w[can_train needs_training training_done],
    4 => %w[needs_training backup_trainer]
  }.freeze

  # 管理者の見立て。スタッフには見せない（HTML の属性・JSON・Turbo Stream にも出さない）。
  # 付けられるレベルは付けるときのサービスで確かめ、ここでは確かめない
  enum :admin_assessment, {
    can_train: 0,       # ▲ 指導できる
    needs_training: 1,  # ▼ 要研修
    training_done: 2,   # ▽ 研修済み
    backup_trainer: 3   # ◇ 指導に不安あり
  }, validate: { allow_nil: true }

  validates :level, numericality: { only_integer: true, in: 0..4 }
  validates :operation_id, uniqueness: { scope: :user_id }
  validate :user_must_be_skill_holder

  # できる人。スキルを持つ人のうちレベル4（◇・▼の人も含む）
  scope :capable, -> { where(level: 4).joins(:user).merge(User.skill_holders) }

  # 教える人の候補。研修画面の一覧と Training の作成時のチェックで共通に使う。
  # レベル4（▼以外）か、レベル3で▲。▲・▽はレベル4では表示しないが、値は残るので候補に入る（NULL も含める）。
  # 並び順つき（4（◇・▼以外）→ 3▲ → 4◇ → スタッフの並び順）。別の順にしたいときは reorder を使う
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

  # 前に確認した版より、マニュアルの版が上がっている（#unread? と同じ条件を SQL で書いたもの）。
  # 一度も確認していない（confirmed_version が NULL の）人は、比較で自然に外れる。
  # 改訂のお知らせのタブの件数のように、まとめて数えるときはこちらを使う（1件ずつ unread? を呼ぶと N+1 になる）
  scope :unread, -> { joins(operation: :manual).where("skills.confirmed_version < manuals.version") }

  # 作業ごとのできる人の数を1回のクエリで返す（{ operation_id => 人数 }）。
  # できる人がいない作業は含まないので、使う側で fetch(id, 0) にする
  def self.capable_counts
    capable.group(:operation_id).count
  end

  def manual_confirmed?(manual)
    operation_id == manual.operation_id && confirmed_version.present? && confirmed_version >= manual.version
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

  # 前に確認した版より、マニュアルの版が上がっている（一度も確認していなければ false）。条件は .unread と同じ
  def unread?
    manual = operation.manual
    confirmed_version.present? && manual.present? && confirmed_version < manual.version
  end

  # マニュアル確認状況。:unconfirmed（未確認）／:unread（改定後 未確認）／:confirmed（確認済み）
  def manual_status
    if confirmed_version.nil?
      :unconfirmed
    elsif unread?
      :unread
    else
      :confirmed
    end
  end

  # 研修済み（誰から・いつ）。この作業でこの人が教わった、完了した研修予定のうち最新のもの（なければ nil）。
  # 1つのスキルで何度も使うので、結果を覚えておく（nil も覚えるので defined? で確かめる）
  def latest_done_training
    return @latest_done_training if defined?(@latest_done_training)

    @latest_done_training = Training.latest_done.includes(:trainer).find_by(operation_id:, trainee_id: user_id)
  end

  # 研修。:done（済み）／:self_taught（なし〈自分で習得〉）／:not_yet（まだ）。
  # 完了した研修があれば、レベルとは関係なく「済み」
  def training_status
    if latest_done_training
      :done
    elsif level >= 3
      :self_taught
    else
      :not_yet
    end
  end

  private

  def user_must_be_skill_holder
    errors.add(:user, :not_skill_holder) if user&.admin?
  end
end
