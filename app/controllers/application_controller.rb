class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :staff_operator?

  private

  # 今操作している人。ログインは作らず、ヘッダーのスイッチで選んだ人を session に持つ。
  # 何も選んでいない（選んだ人がいなくなった）ときは、部長（管理者）になる
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.skill_holders.find_by(id: session[:user_id]) || User.find_by(admin: true)
  end

  # スタッフとして操作しているか。部長のとき、ユーザーが一人もいないときは false
  def staff_operator?
    current_user.present? && !current_user.admin?
  end
end
