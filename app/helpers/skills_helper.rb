# マニュアル確認状況と研修の文。作業ツリーのスタッフ状況とスキルマップのマスの詳細で共通に使う。
# 判定は Skill#manual_status・#training_status で行い、ここでは文にするだけ
module SkillsHelper
  # 「未確認」／「改定後 未確認」／「確認済み」
  def skill_manual_status_label(skill)
    t("skill_statuses.manual.#{skill.manual_status}")
  end

  # 「済み（○○さんから・2026/10/02）」／「なし（自分で習得）」／「まだ」。教えた人が管理者のときは「さん」を付けない
  def skill_training_label(skill)
    return t("skill_statuses.training.#{skill.training_status}") unless skill.training_status == :done

    training = skill.latest_done_training
    trainer = training.trainer.admin? ? training.trainer.name : t("skill_statuses.staff_name", name: training.trainer.name)
    t("skill_statuses.training.done", trainer:, date: l(training.done_on))
  end
end
