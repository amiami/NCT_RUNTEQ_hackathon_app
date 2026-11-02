module Staff
  module Operations
    class ConfirmationsController < ApplicationController
      before_action :require_staff

      def create
        operation = Operation.find(params[:operation_id])
        ManualConfirmation.call(user: current_user, operation: operation, version: params[:version])
        redirect_to staff_operations_path(operation_id: operation.id), notice: t("operations.confirmed_notice"), status: :see_other
      rescue ManualConfirmation::StaleVersion
        redirect_to staff_operations_path(operation_id: operation.id), alert: t("operations.confirmation_stale"), status: :see_other
      end

      private

      def require_staff
        head :forbidden unless staff_operator?
      end
    end
  end
end
