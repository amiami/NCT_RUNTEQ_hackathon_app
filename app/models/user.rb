class User < ApplicationRecord
  validates :name, presence: true
  validates :sort_order, presence: true

  # スキルを持つ人。スキルマップ・できる人の人数・教わる人の候補は必ずこのスコープを使う
  scope :skill_holders, -> { where(admin: false) }
end
