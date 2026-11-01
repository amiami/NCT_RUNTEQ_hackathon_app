module Admin
  class SkillMapsController < Admin::BaseController
    # 行＝作業（分類ごと）、列＝スタッフの表。一覧なので、関連は先にまとめて読み込む（N+1 にしない）
    def show
      @categories = Category.order(:sort_order).includes(:operations)
      @staff = User.skill_holders.order(:sort_order)
      # マスは [人, 作業] で引く。「未読」の判定（unread?）でマニュアルをたどるので一緒に読み込む
      @skills = Skill.where(user: @staff).includes(operation: :manual).index_by { |skill| [ skill.user_id, skill.operation_id ] }
      # { 作業の ID => できる人の数 }。いない作業は入っていないので fetch(id, 0) で使う
      @capable_counts = Skill.capable_counts
    end
  end
end
