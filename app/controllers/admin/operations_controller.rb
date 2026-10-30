module Admin
  class OperationsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.admin.operations") }
    end
  end
end
