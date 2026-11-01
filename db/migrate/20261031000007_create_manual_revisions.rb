class CreateManualRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :manual_revisions do |t|
      t.references :manual, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.integer :version, null: false
      t.text :memo
      t.text :body_before
      t.text :body_after

      t.timestamps
    end
    add_index :manual_revisions, %i[manual_id version], unique: true
  end
end
