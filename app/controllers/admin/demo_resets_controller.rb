module Admin
  class DemoResetsController < ApplicationController
    before_action :require_demo_reset

    def create
      DemoReset.call
      reset_session
      redirect_to root_path, notice: t("demo_reset.completed"), status: :see_other
    end

    private

    def require_demo_reset
      head :not_found unless current_user&.admin?
    end
  end
end
