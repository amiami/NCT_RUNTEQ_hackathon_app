# ヘッダーのスイッチで、操作する人（部長／スタッフ5人のうち1人）を切り替える
class OperatorsController < ApplicationController
  def update
    if params[:user_id].blank?
      session.delete(:user_id)
      redirect_to admin_operations_path, status: :see_other
    elsif (user = User.skill_holders.find_by(id: params[:user_id]))
      session[:user_id] = user.id
      redirect_to staff_operations_path, status: :see_other
    else
      back_to = staff_operator? ? staff_operations_path : admin_operations_path
      redirect_to back_to, alert: t("operators.not_selectable"), status: :see_other
    end
  end
end
