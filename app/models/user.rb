class User < ApplicationRecord
  has_many :skills

  validates :name, presence: true
  validates :sort_order, presence: true

  # スキルを持つ人。スキルマップ・できる人の人数・教わる人の候補は必ずこのスコープを使う
  scope :skill_holders, -> { where(admin: false) }
  # 管理者（部長）。研修の教える人の候補では、いつも最後に並ぶ
  scope :admins, -> { where(admin: true) }
end
