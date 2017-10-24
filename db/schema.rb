# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170913052104) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "identity_providers", force: :cascade do |t|
    t.integer "provider_type", null: false
    t.string "uid", null: false
    t.string "token"
    t.string "secret"
    t.datetime "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.json "auth_info"
    t.uuid "user_id"
    t.index ["user_id", "provider_type"], name: "index_identity_providers_on_user_id_and_provider_type", unique: true
    t.index ["user_id"], name: "index_identity_providers_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "identity_providers", "users"
end
