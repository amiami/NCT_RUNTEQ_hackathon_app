module Staff
  module Operations
    # 自己申告（レベル3・4）。操作しているスタッフ本人のスキルだけを変え、同じ作業の画面に戻る
    class SelfDeclarationsController < ApplicationController
      before_action :require_staff

      def create
        operation = Operation.find(params[:operation_id])
        skill = SelfDeclaration.call(user: current_user, operation: operation, level: params[:level])
        redirect_to staff_operations_path(operation_id: operation.id), status: :see_other,
                    notice: t("operations.self_declared_notice", level: skill.level, name: t("skill_levels.#{skill.level}"))
      rescue SelfDeclaration::NotDeclarable
        redirect_to staff_operations_path(operation_id: operation.id), alert: t("operations.not_declarable"), status: :see_other
      end

      private

      def require_staff
        head :forbidden unless staff_operator?
      end
    end
  end
end
