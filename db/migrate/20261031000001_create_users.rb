class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.boolean :admin, null: false, default: false
      t.integer :sort_order, null: false

      t.timestamps
    end
  end
end
