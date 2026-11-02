# 研修画面（S-3）のカードの一覧。どの作業を出し、誰を教える人・教わる人の候補にするかを、
# レベルと管理者の見立てから求める。並び順は研修タブを開いた時点のものをここで決める
class TrainingBoard
  Card = Data.define(:operation, :trainer_skills, :admins, :target_skills, :trainings, :capable_count) do
    # 教える人：レベル4（◇・▼以外）→ 3▲ → 4◇ → 管理者（いつも最後）
    def trainers
      trainer_skills.map(&:user) + admins
    end

    # 教わる人の候補：レベル0・1と▼の人のうち、この作業で未完了の予定がない人。
    # 名前の横に▼を出すため、User ではなく Skill で返す
    def trainee_skills
      assigned_trainee_ids = trainings.to_set(&:trainee_id)
      target_skills.reject { |skill| assigned_trainee_ids.include?(skill.user_id) }
    end

    # 日付の列：その作業の未完了の予定の期限（期限は作業ごとにそろえるので、どの予定も同じ）。予定がなければ nil
    def due_on
      trainings.first&.due_on
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
    trainings = Training.unfinished.where(operation_id: operation_ids).includes(:trainer, :trainee)
                        .order(:id).group_by(&:operation_id)
    capable_counts = Skill.capable_counts
    admins = User.admins.order(:sort_order, :id).to_a

    cards = Operation.where(id: operation_ids).includes(:category).map do |operation|
      Card.new(
        operation:,
        trainer_skills: trainers.fetch(operation.id, []),
        admins:,
        target_skills: targets.fetch(operation.id),
        trainings: trainings.fetch(operation.id, []),
        capable_count: capable_counts.fetch(operation.id, 0)
      )
    end

    # 「指示が必要」が上 → できる人が少ない順 → 分類の並び順 → 作業の並び順
    cards.sort_by do |card|
      operation = card.operation
      [ card.needs_instruction? ? 0 : 1, card.capable_count, operation.category.sort_order, operation.sort_order, operation.id ]
    end
  end

  # 指示済みの研修（右の一覧）の1件。教わる人のその作業のスキルも持ち、「申告済み」を判定する
  Assigned = Data.define(:training, :trainee_skill) do
    # 教わる人が予定の途中で自己申告してレベル3以上になった（▼の人は研修の対象に残るので出さない）
    def declared_level3_or_above?
      trainee_skill.present? && trainee_skill.level >= 3 && !trainee_skill.needs_training?
    end
  end

  # 指示済みの研修：保存済みの未完了の予定すべて。カードに出ない作業（対象の人がいなくなった作業）の予定も入れ、
  # 部長が「教え終わった」を押す場所がなくならないようにする。並び順は期限が近い順（期限なしは最後）
  # 対象の予定（trainings）を渡すと、その中の未完了の予定だけにする（わたしのスキルの教える予定で使う）
  def self.assigned_trainings(trainings = Training.all)
    trainings = trainings.unfinished.includes(:operation, :trainer, :trainee)
                        .order(Training.arel_table[:due_on].asc.nulls_last, :id).to_a
    skills = Skill.where(operation_id: trainings.map(&:operation_id), user_id: trainings.map(&:trainee_id))
                  .index_by { |skill| [ skill.operation_id, skill.user_id ] }

    trainings.map do |training|
      Assigned.new(training:, trainee_skill: skills[[ training.operation_id, training.trainee_id ]])
    end
  end
end
