module Staff
  class OperationsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.staff.operations") }
    end
  end
end
