module Staff
  class OperationsController < ApplicationController
    include OperationBrowsing

    def index
      load_operation_browser
      @skill_levels = current_user.skills.pluck(:operation_id, :level).to_h if staff_operator?
    end
  end
end
