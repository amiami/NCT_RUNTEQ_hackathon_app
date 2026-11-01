class CreateManuals < ActiveRecord::Migration[8.1]
  def change
    create_table :manuals do |t|
      t.references :operation, null: false, foreign_key: true, index: { unique: true }
      t.integer :kind, null: false
      t.text :body
      t.string :url
      t.integer :version, null: false, default: 1

      t.timestamps
    end
  end
end
