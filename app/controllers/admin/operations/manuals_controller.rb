module Admin
  module Operations
    class ManualsController < Admin::BaseController
      include OperationBrowsing

      before_action :load_manual

      def edit
        show_editor
      end

      def update
        ManualReviser.call(user: current_user, manual: @manual, **revision_params.to_h.symbolize_keys)
        redirect_to admin_operations_path(operation_id: @manual.operation_id),
          notice: t("operations.revised_notice"), status: :see_other
      rescue ManualReviser::InvalidInput => error
        @revision_error = t("operations.#{error.message}")
        show_editor(status: :unprocessable_content)
      rescue ActiveRecord::RecordInvalid
        @revision_error = t("operations.revision_invalid")
        show_editor(status: :unprocessable_content)
      rescue ManualReviser::StaleVersion
        @revision_error = t("operations.revision_stale")
        if @manual.external?
          redirect_to admin_operations_path(operation_id: @manual.operation_id),
            alert: t("operations.external_revision_stale"), status: :see_other
        else
          show_editor(status: :conflict)
        end
      rescue ManualReviser::NotAdmin
        head :forbidden
      end

      private

      def load_manual
        @manual = Manual.find_by!(operation_id: params[:operation_id])
        raise ActiveRecord::RecordNotFound if action_name == "edit" && !@manual.internal?
      end

      def revision_params
        fields = @manual.internal? ? [ :body, :memo, :version ] : [ :memo, :version ]
        params.require(:manual).permit(*fields).with_defaults(body: nil, memo: nil, version: nil)
      end

      def show_editor(status: :ok)
        @manual.reload
        @editing_manual = true
        @revision_body = action_name == "update" ? revision_params[:body] : @manual.body
        @revision_memo = action_name == "update" ? revision_params[:memo] : ""
        # 競合時は古い版を維持し、再送で新しい手順を上書きさせない。
        @revision_version = action_name == "update" ? revision_params[:version] : @manual.version
        load_operation_browser
        render "admin/operations/index", status: status
      end
    end
  end
end
