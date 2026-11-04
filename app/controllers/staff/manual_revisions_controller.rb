module Staff
  class ManualRevisionsController < ApplicationController
    def index
      @revisions = ManualRevision.newest_first.includes(manual: :operation)
      @skills_by_operation = if staff_operator?
        current_user.skills.includes(operation: :manual).index_by(&:operation_id)
      else
        {}
      end
    end
  end
end
