class CreateTrainings < ActiveRecord::Migration[8.1]
  def change
    create_table :trainings do |t|
      t.references :operation, null: false, foreign_key: true
      t.references :trainer, null: false, foreign_key: { to_table: :users }
      t.references :trainee, null: false, foreign_key: { to_table: :users }
      t.date :due_on
      t.integer :status, null: false, default: 0
      t.date :done_on

      t.timestamps
    end
    # 2 = done。完了していない予定だけを対象に、同じ作業・同じ教わる人を1件にする。
    # Training の enum の値を変えるときは、このインデックスも作り直す
    add_index :trainings, %i[operation_id trainee_id], unique: true, where: "status <> 2",
                                                       name: "index_trainings_open_per_trainee"
  end
end
