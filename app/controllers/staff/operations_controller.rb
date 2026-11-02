module Staff
  class OperationsController < ApplicationController
    include OperationBrowsing

    def index
      load_operation_browser
      if staff_operator?
        skills = current_user.skills.select(:operation_id, :level, :confirmed_version).index_by(&:operation_id)
        @skill_levels = skills.transform_values(&:level)
        @confirmation_skill = skills[@operation&.id]
      end
    end
  end
end
