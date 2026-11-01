class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false, index: { unique: true }
      t.integer :sort_order, null: false

      t.timestamps
    end
  end
end
