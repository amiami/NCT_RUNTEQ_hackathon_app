module Staff
  class OperationsController < ApplicationController
    include OperationBrowsing

    def index
      load_operation_browser
      if staff_operator?
        # unread? は operation.manual をたどるので、先に読み込んで N+1 を避ける
        skills = current_user.skills.includes(operation: :manual).index_by(&:operation_id)
        @skill_levels = skills.transform_values(&:level)
        @relearn_operation_ids = skills.values.select(&:unread?).map(&:operation_id)
        @confirmation_skill = skills[@operation&.id]
      end
    end
  end
end
