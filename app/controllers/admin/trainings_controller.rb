module Admin
  class TrainingsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.admin.trainings") }
    end
  end
end
