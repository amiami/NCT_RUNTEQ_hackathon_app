module Staff
  class SkillsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.staff.skills") }
    end
  end
end
