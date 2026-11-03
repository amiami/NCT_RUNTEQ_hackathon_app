module Admin
  class SkillsController < Admin::BaseController
    # スキルマップのマス1つ分の詳細。スキルマップの表の上の Turbo Frame（skill_detail）に入る
    def show
      # 名前・作業名と、マニュアル確認状況（unread? でマニュアルをたどる）に使うので一緒に読み込む
      @skill = Skill.includes(:user, operation: :manual).find(params[:id])
    end
  end
end
