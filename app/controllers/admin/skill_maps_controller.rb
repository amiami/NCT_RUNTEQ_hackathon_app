module Admin
  class SkillMapsController < ApplicationController
    def show
      render "shared/placeholder", locals: { title: t("navigation.admin.skill_map") }
    end
  end
end
