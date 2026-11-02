module OperationsHelper
  def operation_category_kind_label(operations)
    kinds = operations.filter_map { |operation| operation.manual&.kind }.uniq
    Manual.kinds.keys.filter_map do |kind|
      t("operations.kinds.#{kind}") if kinds.include?(kind)
    end.join("・")
  end

  def operation_selection_path(operation)
    if admin_page?
      admin_operations_path(operation_id: operation.id)
    else
      staff_operations_path(operation_id: operation.id)
    end
  end

  def operation_revision_date(manual)
    manual&.latest_revision&.created_at&.in_time_zone
  end

  def operation_staff_confirmation(row, manual)
    state = if row.confirmed_version.nil? || manual.nil?
      "unconfirmed"
    elsif row.confirmed_version < manual.version
      "revised"
    else
      "confirmed"
    end
    t("operations.staff_status.confirmations.#{state}")
  end

  def operation_staff_training(row)
    if row.training
      t("operations.staff_status.trained", trainer: row.training.trainer.name,
        date: l(row.training.done_on, format: :operation_full_date))
    elsif row.level >= 3
      t("operations.staff_status.self_learned")
    else
      t("operations.staff_status.not_trained")
    end
  end

  def manual_site_url(manual)
    uri = URI.parse(manual.url.to_s)
    manual.url if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
