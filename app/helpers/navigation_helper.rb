module NavigationHelper
  def application_page?
    controller_path.start_with?("admin/", "staff/")
  end

  def admin_page?
    controller_path.start_with?("admin/")
  end

  def navigation_current?(path)
    current_page?(path) || (path == staff_operations_path && current_page?(root_path))
  end

  def navigation_counts
    # 操作ユーザー機能との接続時に、current_userから集計した件数を返す。
    {}
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
