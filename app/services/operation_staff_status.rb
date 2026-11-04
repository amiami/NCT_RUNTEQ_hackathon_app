# 作業ツリーの「この作業のスタッフ状況」。スキルを持つ人ごとに、その人のこの作業の Skill を返す。
# 確認状況・研修の判定は Skill#manual_status・#training_status で行う（スキルマップの詳細と同じ）
class OperationStaffStatus
  Row = Data.define(:user, :skill)

  def self.rows(operation)
    # 確認状況の判定（Skill#unread?）で読むマニュアルを、全員で1回にするため、どのスキルにも同じ operation を入れる。
    # operation.skills で読むと、渡された operation に読んだ結果が残るので、Skill.where で読む
    skills = Skill.where(operation:).each { |skill| skill.operation = operation }.index_by(&:user_id)
    # 研修済み（誰から・いつ）は1回でまとめて読み、それぞれのスキルに入れておく（1件ずつ読むと N+1 になる）
    trainings = Training.latest_done.where(operation: operation).includes(:trainer).index_by(&:trainee_id)

    User.skill_holders.order(:sort_order, :id).map do |user|
      # スキルがまだない人はレベル0として扱う。閲覧ではレコードを作らないので保存しない
      skill = skills[user.id] || Skill.new(user:, operation:, level: 0)
      skill.latest_done_training = trainings[user.id]
      Row.new(user:, skill:)
    end
  end
end
