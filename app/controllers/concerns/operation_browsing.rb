module OperationBrowsing
  extend ActiveSupport::Concern

  private

  def load_operation_browser
    @categories = Category.order(:sort_order, :id).preload(operations: { manual: :latest_revision }).to_a
    @operations_by_category = @categories.to_h do |category|
      [ category.id, category.operations.sort_by { |operation| [ operation.sort_order, operation.id ] } ]
    end
    operations = @operations_by_category.values.flatten
    @operation = if params[:operation_id].blank?
      operations.first
    else
      operations.find { |operation| operation.id.to_s == params[:operation_id] } || raise(ActiveRecord::RecordNotFound)
    end
    @capable_counts = Skill.capable_counts
  end
end
