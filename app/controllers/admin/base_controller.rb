module Admin
  # 管理者の画面の共通部分。スタッフとして操作しているときは、スタッフの画面に戻す
  class BaseController < ApplicationController
    before_action :require_admin

    private

    def require_admin
      redirect_to staff_operations_path, alert: t("operators.admin_only") if staff_operator?
    end
  end
end
