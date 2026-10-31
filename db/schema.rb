# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_31_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "manuals", force: :cascade do |t|
    t.bigint "operation_id", null: false
    t.integer "kind", null: false
    t.text "body"
    t.string "url"
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["operation_id"], name: "index_manuals_on_operation_id", unique: true
  end

  create_table "operations", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.integer "sort_order", null: false
    t.string "season_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "name"], name: "index_operations_on_category_id_and_name", unique: true
  end

  create_table "skill_level_changes", force: :cascade do |t|
    t.bigint "skill_id", null: false
    t.bigint "changed_by_id", null: false
    t.integer "from_level", null: false
    t.integer "to_level", null: false
    t.integer "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_skill_level_changes_on_changed_by_id"
    t.index ["skill_id"], name: "index_skill_level_changes_on_skill_id"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "operation_id", null: false
    t.integer "level", default: 0, null: false
    t.integer "confirmed_version"
    t.integer "admin_assessment"
    t.datetime "admin_assessed_at"
    t.bigint "admin_assessed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_assessed_by_id"], name: "index_skills_on_admin_assessed_by_id"
    t.index ["operation_id"], name: "index_skills_on_operation_id"
    t.index ["user_id", "operation_id"], name: "index_skills_on_user_id_and_operation_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "admin", default: false, null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "manuals", "operations"
  add_foreign_key "operations", "categories"
  add_foreign_key "skill_level_changes", "skills"
  add_foreign_key "skill_level_changes", "users", column: "changed_by_id"
  add_foreign_key "skills", "operations"
  add_foreign_key "skills", "users"
  add_foreign_key "skills", "users", column: "admin_assessed_by_id"
end
