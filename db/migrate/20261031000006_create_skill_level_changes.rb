class CreateSkillLevelChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_level_changes do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :changed_by, null: false, foreign_key: { to_table: :users }
      t.integer :from_level, null: false
      t.integer :to_level, null: false
      t.integer :reason, null: false

      t.timestamps
    end
  end
end
