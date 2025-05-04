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

ActiveRecord::Schema[8.0].define(version: 2025_05_04_131621) do
  create_table "attachments", force: :cascade do |t|
    t.string "name"
    t.string "content_type"
    t.binary "data"
    t.integer "entry_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "encryption_key_id", null: false
    t.text "encrypted_key"
    t.text "initialization_vector"
    t.string "file_path"
    t.index ["encryption_key_id"], name: "index_attachments_on_encryption_key_id"
    t.index ["entry_id"], name: "index_attachments_on_entry_id"
    t.index ["file_path"], name: "index_attachments_on_file_path", unique: true
  end

  create_table "encryption_keys", force: :cascade do |t|
    t.text "public_key"
    t.text "private_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "entries", force: :cascade do |t|
    t.datetime "entry_date"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category", default: "Diary", null: false
    t.integer "encryption_key_id", null: false
    t.text "encrypted_aes_key"
    t.text "initialization_vector"
    t.index ["encryption_key_id"], name: "index_entries_on_encryption_key_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  add_foreign_key "attachments", "encryption_keys"
  add_foreign_key "attachments", "entries"
  add_foreign_key "entries", "encryption_keys"
end
