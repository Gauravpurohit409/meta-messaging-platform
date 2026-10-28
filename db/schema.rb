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

ActiveRecord::Schema[8.0].define(version: 2026_10_28_102000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaign_recipients", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.string "phone_number", null: false
    t.jsonb "parameters", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.string "message_id"
    t.string "error_code"
    t.text "error_message"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "phone_number"], name: "index_campaign_recipients_on_campaign_id_and_phone_number", unique: true
    t.index ["campaign_id"], name: "index_campaign_recipients_on_campaign_id"
    t.index ["message_id"], name: "index_campaign_recipients_on_message_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "template_id", null: false
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "default_parameters", default: {}, null: false
    t.text "failure_reason"
    t.datetime "scheduled_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "total_recipients", default: 0, null: false
    t.integer "sent_count", default: 0, null: false
    t.integer "delivered_count", default: 0, null: false
    t.integer "read_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_campaigns_on_status"
    t.index ["template_id"], name: "index_campaigns_on_template_id"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "templates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "meta_template_id"
    t.string "name", null: false
    t.string "language", default: "en_US", null: false
    t.string "category", default: "UTILITY", null: false
    t.string "status", default: "draft", null: false
    t.string "header_text"
    t.text "body", null: false
    t.string "footer_text"
    t.jsonb "buttons", default: [], null: false
    t.jsonb "example_values", default: {}, null: false
    t.text "rejection_reason"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meta_template_id"], name: "index_templates_on_meta_template_id"
    t.index ["status"], name: "index_templates_on_status"
    t.index ["user_id", "name", "language"], name: "index_templates_on_user_id_and_name_and_language", unique: true
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", null: false
    t.string "company"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.boolean "processed", default: false, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "whatsapp_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "waba_id"
    t.string "phone_number_id"
    t.text "access_token"
    t.string "verify_token", null: false
    t.string "display_phone"
    t.boolean "demo_mode", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_whatsapp_accounts_on_user_id", unique: true
  end

  add_foreign_key "campaign_recipients", "campaigns"
  add_foreign_key "campaigns", "templates"
  add_foreign_key "campaigns", "users"
  add_foreign_key "templates", "users"
  add_foreign_key "whatsapp_accounts", "users"
end
