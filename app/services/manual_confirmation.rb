class ManualConfirmation
  class NotStaff < StandardError; end
  class StaleVersion < StandardError; end

  def self.call(user:, operation:, version:)
    raise NotStaff unless User.skill_holders.exists?(id: user&.id)

    # 同じ人からの二重送信や、未作成スキルの重複作成を防ぐ。
    # with_lock のトランザクションで確認版・レベル・履歴を一緒に保存する。
    user.with_lock do
      manual = Manual.find_by!(operation: operation)
      raise StaleVersion unless version.to_s == manual.version.to_s

      skill = user.skills.find_or_initialize_by(operation: operation)
      skill.lock! if skill.persisted?
      next skill if skill.manual_confirmed?(manual)

      previous_level = skill.level
      skill.confirmed_version = manual.version
      skill.level = 1 if previous_level.zero?
      skill.save!

      if previous_level.zero?
        SkillLevelChange.create!(skill: skill, changed_by: user,
          from_level: previous_level, to_level: skill.level, reason: :confirmed)
      end
      skill
    end
  end
end
