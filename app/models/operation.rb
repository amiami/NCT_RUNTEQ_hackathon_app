class Operation < ApplicationRecord
  belongs_to :category
  has_one :manual
  has_many :skills

  validates :name, presence: true, uniqueness: { scope: :category_id }
  validates :sort_order, presence: true

  # できる人の数。スキルを持つ人のうちレベル4の人数（◇・▼の人も数える）
  def capable_count
    skills.where(level: 4).joins(:user).merge(User.skill_holders).count
  end
end
