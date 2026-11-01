module NavigationHelper
  def application_page?
    controller_path.start_with?("admin/", "staff/")
  end

  def admin_page?
    controller_path.start_with?("admin/")
  end

  def navigation_current?(path)
    current_page?(path)
  end

  # タブの件数。共通レイアウトから shared/header に渡す。どの件数も問い合わせの回数が一定（N+1 にしない）。
  # - スタッフ：わたしのスキル（完了していない教える予定・教わる予定）と、改訂のお知らせ（未確認）
  # - 部長：スキルマップ（できる人が1人以下の作業）。部長がスタッフの画面を開いても、スタッフ用の件数は数えない
  def navigation_counts
    return {} if current_user.nil?

    if staff_operator?
      {
        training_count: Training.unfinished.involving(current_user).count,
        unread_count: current_user.skills.unread.count
      }
    else
      { skill_map_count: Operation.few_capable_count }
    end
  end

  # ヘッダーのスイッチに渡す、操作する人の状態。選べるのはスキルを持つ人（管理者以外）だけ
  def operator_switch
    {
      staff: staff_operator?,
      selected_id: current_user&.id,
      candidates: User.skill_holders.order(:sort_order, :id).to_a
    }
  end

  def navigation_items
    if admin_page?
      [
        [ t("navigation.admin.operations"), admin_operations_path ],
        [ t("navigation.admin.skill_map"), admin_skill_map_path ],
        [ t("navigation.admin.trainings"), admin_trainings_path ],
        [ t("navigation.admin.manual_revisions"), admin_manual_revisions_path ]
      ]
    else
      [
        [ t("navigation.staff.operations"), staff_operations_path ],
        [ t("navigation.staff.skills"), staff_skills_path ],
        [ t("navigation.staff.manual_revisions"), staff_manual_revisions_path ]
      ]
    end
  end
end
