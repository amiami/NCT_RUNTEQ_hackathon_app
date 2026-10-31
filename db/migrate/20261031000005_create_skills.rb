class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :operation, null: false, foreign_key: true
      t.integer :level, null: false, default: 0
      t.integer :confirmed_version
      t.integer :admin_assessment
      t.datetime :admin_assessed_at
      t.references :admin_assessed_by, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :skills, %i[user_id operation_id], unique: true
  end
end
