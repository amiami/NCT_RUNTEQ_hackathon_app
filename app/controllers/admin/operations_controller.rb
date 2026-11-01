module Admin
  class OperationsController < Admin::BaseController
    include OperationBrowsing

    def index
      load_operation_browser
    end
  end
end
