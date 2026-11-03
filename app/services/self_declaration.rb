# スタッフ本人の自己申告（「先輩のもとでできる」でレベル3、「最後まで1人でできる」でレベル4）。
# レベルの更新と skill_level_changes の記録を1つのトランザクションで行う。
# 研修を受けたかどうかは見ない。管理者の見立てと確認した版は変えない
class SelfDeclaration
  class NotStaff < StandardError; end
  class NotDeclarable < StandardError; end

  # 申告できるレベルごとの、元のレベル。レベル0（マニュアル未確認）からは申告できず、0〜2へ下げる申告もない
  DECLARABLE_FROM = {
    3 => [ 1, 2, 4 ],
    4 => [ 1, 2, 3 ]
  }.freeze

  def self.call(user:, operation:, level:)
    raise NotStaff unless User.skill_holders.exists?(id: user&.id)

    level = Integer(level, exception: false)
    raise NotDeclarable unless DECLARABLE_FROM.key?(level)

    # 二度押しで記録が重ならないよう、本人をロックしてから今のレベルを読み直す
    user.with_lock do
      skill = user.skills.find_by(operation: operation)
      raise NotDeclarable if skill.nil?

      skill.lock!
      next skill if skill.level == level
      raise NotDeclarable unless DECLARABLE_FROM.fetch(level).include?(skill.level)

      previous_level = skill.level
      skill.update!(level: level)
      SkillLevelChange.create!(skill: skill, changed_by: user,
        from_level: previous_level, to_level: level, reason: :self_declared)
      skill
    end
  end
end
