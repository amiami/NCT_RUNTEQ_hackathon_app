class CreateOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :operations do |t|
      t.references :category, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :sort_order, null: false
      t.string :season_note

      t.timestamps
    end
    add_index :operations, %i[category_id name], unique: true
  end
end
