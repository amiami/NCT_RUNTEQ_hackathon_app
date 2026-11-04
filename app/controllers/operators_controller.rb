# ヘッダーのスイッチで、操作する人（部長／スタッフ5人のうち1人）を切り替える
class OperatorsController < ApplicationController
  def update
    if params[:user_id].blank?
      session.delete(:user_id)
      redirect_to admin_operations_path, status: :see_other
    elsif (user = User.skill_holders.find_by(id: params[:user_id]))
      destination = staff_switch_destination
      session[:user_id] = user.id
      redirect_to destination, status: :see_other
    else
      back_to = staff_operator? ? staff_operations_path : admin_operations_path
      redirect_to back_to, alert: t("operators.not_selectable"), status: :see_other
    end
  end

  private

  # 選択前もスタッフのときだけ、名前ボタンから渡されたスタッフ画面を保つ。
  # 外部URLや管理者画面を受け付けず、作業マニュアルでは選択中の作業だけ引き継ぐ。
  def staff_switch_destination
    allowed_paths = [ staff_operations_path, staff_skills_path, staff_manual_revisions_path ]
    return staff_operations_path unless staff_operator? && allowed_paths.include?(params[:return_to])
    return staff_operations_path(params.permit(:operation_id)) if params[:return_to] == staff_operations_path

    params[:return_to]
  end
end
