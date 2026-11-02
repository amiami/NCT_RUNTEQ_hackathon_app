module TrainingsHelper
  DUE_SOON_DAYS = 14

  # 期限まで14日以内か（期限を過ぎていても true）。研修画面の日付と、わたしのスキルの期限をオレンジにする
  def due_soon?(date)
    date.present? && date <= Date.current + DUE_SOON_DAYS
  end

  # 「期限：2026/11/30」／「期限：未設定」
  def training_due_label(date)
    date ? t("training_due_on.date", date: l(date)) : t("training_due_on.none")
  end

  # 管理者の見立ての記号（▲・▼・▽・◇）。今のレベルで意味のある見立てだけ出す（Skill#assessment_meaningful?）。
  # 管理者の画面だけで使う。スタッフの画面では呼ばない（HTML の属性にも出さない）
  def assessment_mark(skill)
    return unless skill.assessment_meaningful?

    key = skill.admin_assessment
    tag.span(t("admin_assessments.#{key}.mark"), class: "assessment-mark", title: t("admin_assessments.#{key}.label"))
  end
end
