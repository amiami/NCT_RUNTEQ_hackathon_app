# 研修画面（S-3）のカードの一覧。どの作業を出し、誰を教える人・教わる人の候補にするかを、
# レベルと管理者の見立てから求める。並び順は研修タブを開いた時点のものをここで決める
class TrainingBoard
  Card = Data.define(:operation, :trainer_skills, :admins, :target_skills, :assigned_trainee_ids, :capable_count) do
    # 教える人：レベル4（◇・▼以外）→ 3▲ → 4◇ → 管理者（いつも最後）
    def trainers
      trainer_skills.map(&:user) + admins
    end

    # 教わる人の候補：レベル0・1と▼の人のうち、この作業で未完了の予定がない人。
    # 名前の横に▼を出すため、User ではなく Skill で返す
    def trainee_skills
      target_skills.reject { |skill| assigned_trainee_ids.include?(skill.user_id) }
    end

    # 対象の人（レベル0・1と▼）のうち、未完了の予定がある人が いない／一部／全員
    def status
      assigned = target_skills.size - trainee_skills.size
      if assigned.zero?
        :unassigned
      elsif trainee_skills.empty?
        :assigned
      else
        :partially_assigned
      end
    end

    # 「指示が必要」：未指示と一部 指示済み
    def needs_instruction?
      status != :assigned
    end
  end

  # 作業の数によらず、問い合わせの回数が変わらないように、まとめて読み込んでから作業ごとに振り分ける
  def self.cards
    targets = Skill.training_targets.includes(:user).group_by(&:operation_id)
    operation_ids = targets.keys
    trainers = Skill.trainer_candidates.where(operation_id: operation_ids).includes(:user).group_by(&:operation_id)
    assigned = Training.unfinished.where(operation_id: operation_ids).pluck(:operation_id, :trainee_id)
                       .group_by(&:first).transform_values { |pairs| pairs.map(&:last).to_set }
    capable_counts = Skill.capable_counts
    admins = User.where(admin: true).order(:sort_order, :id).to_a

    cards = Operation.where(id: operation_ids).includes(:category).map do |operation|
      Card.new(
        operation:,
        trainer_skills: trainers.fetch(operation.id, []),
        admins:,
        target_skills: targets.fetch(operation.id),
        assigned_trainee_ids: assigned.fetch(operation.id, Set.new),
        capable_count: capable_counts.fetch(operation.id, 0)
      )
    end

    # 「指示が必要」が上 → できる人が少ない順 → 分類の並び順 → 作業の並び順
    cards.sort_by do |card|
      operation = card.operation
      [ card.needs_instruction? ? 0 : 1, card.capable_count, operation.category.sort_order, operation.sort_order, operation.id ]
    end
  end
end
