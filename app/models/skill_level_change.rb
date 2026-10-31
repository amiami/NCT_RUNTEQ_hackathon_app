class SkillLevelChange < ApplicationRecord
  belongs_to :skill
  belongs_to :changed_by, class_name: "User"

  enum :reason, {
    confirmed: 0,          # マニュアルを確認した
    trained: 1,            # 教え終わった
    self_declared: 2,      # 自己申告
    declaration_undone: 3  # 申告を取り消した
  }, validate: true

  validates :from_level, :to_level, presence: true
end
