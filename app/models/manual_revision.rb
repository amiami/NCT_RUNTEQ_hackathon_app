class ManualRevision < ApplicationRecord
  belongs_to :manual
  belongs_to :user

  # 改定1回につき1行。初版（第1版）の行は作らないので、版は2から
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 2 },
                      uniqueness: { scope: :manual_id }

  # 改訂履歴の並び順。同じ時刻なら後に記録したほうを上にする
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
