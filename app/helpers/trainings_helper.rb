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
end
