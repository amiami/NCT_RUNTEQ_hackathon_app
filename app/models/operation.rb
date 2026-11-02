class Operation < ApplicationRecord
  belongs_to :category
  has_one :manual
  has_many :skills
  has_many :trainings

  validates :name, presence: true, uniqueness: { scope: :category_id }
  validates :sort_order, presence: true

  # できる人の数。スキルを持つ人のうちレベル4の人数（◇・▼の人も数える）。
  # 一覧で作業ごとに呼ぶと N+1 になるので、一覧では Skill.capable_counts を使う
  def capable_count
    skills.capable.count
  end

  # できる人が1人以下の作業の数（スキルマップのタブの件数）。0人の作業も数える。
  # Skill.capable_counts はできる人がいない作業を含まないので、「作業の総数 − できる人が2人以上の作業の数」で求める
  def self.few_capable_count
    count - Skill.capable_counts.count { |_operation_id, capable| capable >= 2 }
  end
end
