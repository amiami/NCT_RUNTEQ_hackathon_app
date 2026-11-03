# わたしのスキル（S-6）の左の欄：レベル0〜4ごとの件数と、分類ごとの作業の一覧。
# 分類・作業・マニュアル・スキル・研修予定をまとめて読み、作業が増えても問い合わせの回数が変わらないようにする。
# スタッフの画面で使うので、管理者の見立ては行に持たせない
class MySkillList
  LEVELS = (0..4)

  # 一覧の1行。「研修済み」は Skill#training_status、「再確認」は Skill#unread? だけで決める
  Row = Data.define(:skill) do
    def operation = skill.operation
    def level = skill.level
    def trained? = skill.training_status == :done
    def reconfirm? = skill.unread?
  end

  attr_reader :level_counts, :categories

  def self.for(user)
    skills = user.skills.includes(operation: [ :category, :manual ]).to_a
    # 研修済み（誰から・いつ）は1回でまとめて読み、それぞれのスキルに入れておく（1件ずつ読むと N+1 になる）
    done = Training.latest_done.where(trainee: user).includes(:trainer).index_by(&:operation_id)
    skills.each { |skill| skill.latest_done_training = done[skill.operation_id] }
    new(skills)
  end

  def initialize(skills)
    @level_counts = LEVELS.index_with { |level| skills.count { |skill| skill.level == level } }
    # 分類の並び順 → 作業の並び順
    @categories = skills.sort_by { |skill| sort_key(skill.operation) }
                        .group_by { |skill| skill.operation.category }
                        .map { |category, category_skills| [ category, category_skills.map { |skill| Row.new(skill:) } ] }
  end

  private

  def sort_key(operation)
    [ operation.category.sort_order, operation.category_id, operation.sort_order, operation.id ]
  end
end
