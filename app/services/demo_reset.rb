# デモ専用。削除と再投入を同じトランザクションで行い、失敗時は元に戻す。
class DemoReset
  def self.call
    ApplicationRecord.transaction do
      # 同時に押されてもリセット同士を直列にする（トランザクション終了時に解除）。
      ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(34121)")
      [ SkillLevelChange, Training, ManualRevision, Skill, Manual, Operation, Category, User ].each(&:delete_all)
      Rails.application.load_seed
    end
  end
end
