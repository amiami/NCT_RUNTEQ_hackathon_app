class OperationStaffStatus
  Row = Data.define(:user, :level, :confirmed_version, :training)

  def self.rows(operation)
    skills = operation.skills.select(:user_id, :level, :confirmed_version).index_by(&:user_id)
    trainings = Training.latest_done.where(operation: operation).includes(:trainer).index_by(&:trainee_id)

    User.skill_holders.order(:sort_order, :id).map do |user|
      skill = skills[user.id]
      Row.new(user: user, level: skill&.level || 0,
        confirmed_version: skill&.confirmed_version, training: trainings[user.id])
    end
  end
end
