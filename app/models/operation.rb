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
end
