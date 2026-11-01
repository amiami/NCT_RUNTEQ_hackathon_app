module Skills
  # 管理者の見立てを、複数のマスまとめて保存する（スキルマップの「変更を保存」）。
  # 付けられるレベルかどうかは、値が変わるマスだけ確かめる（4▲の人を▲のまま送ってもエラーにしない）。
  # 1つでも付けられない組み合わせがあれば、全部保存しない。レベルは変えず、skill_level_changes にも記録しない
  class AssessmentUpdate
    # 見立てごとの、付けられるレベル。▽（training_done）は「教え終わった」で自動で付くので、ここでは付けられない
    ASSIGNABLE_LEVELS = {
      "can_train" => 3,
      "needs_training" => 3,
      "backup_trainer" => 4
    }.freeze

    attr_reader :errors

    # assessments は { スキルの ID => 見立て }。見立てが空（""・nil）なら「なし」
    def initialize(admin:, assessments:)
      @admin = admin
      @assessments = assessments.to_h.to_h { |skill_id, assessment| [ skill_id.to_i, assessment.presence ] }
      @errors = []
    end

    def save
      changed = Skill.includes(:user, :operation).find(@assessments.keys).reject do |skill|
        skill.admin_assessment == @assessments[skill.id]
      end
      changed.each { |skill| check_assignable(skill, @assessments[skill.id]) }
      return false if errors.any?

      now = Time.current
      Skill.transaction do
        changed.each { |skill| apply(skill, @assessments[skill.id], now) }
      end
      true
    end

    private

    def check_assignable(skill, assessment)
      return if assessment.nil?

      level = ASSIGNABLE_LEVELS[assessment]
      if level.nil?
        errors << I18n.t("skills.assessments.errors.invalid", **names(skill))
      elsif skill.level != level
        errors << I18n.t("skills.assessments.errors.not_assignable",
                         **names(skill), assessment: I18n.t("admin_assessments.#{assessment}"), level:)
      end
    end

    # 「なし」のときは、見立て・日時・付けた人の3つを空にする
    def apply(skill, assessment, now)
      if assessment.nil?
        skill.update!(admin_assessment: nil, admin_assessed_at: nil, admin_assessed_by: nil)
      else
        skill.update!(admin_assessment: assessment, admin_assessed_at: now, admin_assessed_by: @admin)
      end
    end

    def names(skill)
      { user: skill.user.name, operation: skill.operation.name }
    end
  end
end
