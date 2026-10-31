class Manual < ApplicationRecord
  belongs_to :operation
  has_many :manual_revisions

  # 値を url にしない（カラム url と url? などのメソッドがぶつかるため）
  enum :kind, { internal: 0, external: 1 }, validate: true

  validates :operation_id, uniqueness: true
  validates :version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :body, presence: true, if: :internal?
  validates :url, presence: true, if: :external?

  # 手順の一覧。本文の1行が1ステップで、空行は除く
  def steps
    body.to_s.lines.map(&:strip).compact_blank
  end
end
