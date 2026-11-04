# 管理者の見立ての印（▲・▼・▽・◇ のアイコン）。スキルマップのマス・研修画面の名前の横・凡例で共通に使う。
# 管理者の画面だけで使う。スタッフの画面では呼ばない（HTML の属性にも出さない）
module AdminAssessmentsHelper
  # 見立てごとのアイコンの形（16×16）。記号（admin_assessments の mark）と同じ形を、角を少し丸めて描く。
  # 塗りの三角は、同じ色の線を重ねて角を丸める
  ASSESSMENT_ICON_SHAPES = {
    "can_train" => { d: "M8 3.5 13 12H3Z", filled: true },              # ▲
    "needs_training" => { d: "M8 12.5 3 4h10Z", filled: true },         # ▼
    "training_done" => { d: "M8 12.2 3.4 4.4h9.2Z", filled: false },    # ▽
    "backup_trainer" => { d: "M8 2.6 13.4 8 8 13.4 2.6 8Z", filled: false } # ◇
  }.freeze

  # スキルの見立ての印。今のレベルで意味のある見立てだけ出す（Skill#assessment_meaningful?）
  def assessment_mark(skill)
    assessment_icon(skill.admin_assessment) if skill.assessment_meaningful?
  end

  # 見立てのアイコン。色はまわりの文字の色（マスなら数字と同じ色）。
  # マウスを乗せると名前が出て、読み上げでも名前を読む。名前を横に書く凡例では labelled: false にして、二重に読ませない
  def assessment_icon(assessment, labelled: true)
    name = t("admin_assessments.#{assessment}.label")
    attributes = labelled ? { role: "img", "aria-label": name, title: name } : { "aria-hidden": "true" }
    tag.span(class: "assessment-mark assessment-mark-#{assessment}", **attributes) do
      assessment_icon_svg(ASSESSMENT_ICON_SHAPES.fetch(assessment.to_s))
    end
  end

  private

  def assessment_icon_svg(shape)
    tag.svg("viewBox" => "0 0 16 16", "aria-hidden" => "true") do
      tag.path(d: shape[:d], fill: shape[:filled] ? "currentColor" : "none", stroke: "currentColor",
               "stroke-width" => shape[:filled] ? 2 : 1.8, "stroke-linejoin" => "round")
    end
  end
end
