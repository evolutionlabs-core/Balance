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

ActiveRecord::Schema[8.1].define(version: 2026_09_09_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.string "base_type", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "detail_type", null: false
    t.string "name", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "account_type"], name: "index_accounts_on_workspace_id_and_account_type"
    t.index ["workspace_id", "base_type"], name: "index_accounts_on_workspace_id_and_base_type"
    t.index ["workspace_id", "name"], name: "index_accounts_on_workspace_id_and_name", unique: true
    t.index ["workspace_id", "role"], name: "index_accounts_on_workspace_id_and_role", unique: true, where: "(role IS NOT NULL)"
    t.index ["workspace_id"], name: "index_accounts_on_workspace_id"
  end

  create_table "contact_roles", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "role"], name: "index_contact_roles_on_contact_id_and_role", unique: true
    t.index ["contact_id"], name: "index_contact_roles_on_contact_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "contact_kind", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "active"], name: "index_contacts_on_workspace_id_and_active"
    t.index ["workspace_id", "name"], name: "index_contacts_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_contacts_on_workspace_id"
  end

  create_table "expense_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "amount_kobo", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "expense_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_expense_lines_on_account_id"
    t.index ["expense_id", "position"], name: "index_expense_lines_on_expense_id_and_position", unique: true
    t.index ["expense_id"], name: "index_expense_lines_on_expense_id"
    t.check_constraint "\"position\" >= 0", name: "expense_lines_nonnegative_position"
    t.check_constraint "amount_kobo > 0", name: "expense_lines_positive_amount"
  end

  create_table "expenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "journal_entry_id"
    t.text "memo"
    t.bigint "payee_contact_id"
    t.bigint "payment_account_id", null: false
    t.date "payment_date", null: false
    t.string "status", default: "draft", null: false
    t.bigint "total_kobo", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["journal_entry_id"], name: "index_expenses_on_journal_entry_id", unique: true, where: "(journal_entry_id IS NOT NULL)"
    t.index ["payee_contact_id"], name: "index_expenses_on_payee_contact_id"
    t.index ["payment_account_id"], name: "index_expenses_on_payment_account_id"
    t.index ["workspace_id", "payee_contact_id", "payment_date", "total_kobo"], name: "index_expenses_for_transaction_duplicate_detection"
    t.index ["workspace_id", "payment_date"], name: "index_expenses_on_workspace_id_and_payment_date"
    t.index ["workspace_id", "status"], name: "index_expenses_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_expenses_on_workspace_id"
    t.check_constraint "status::text = 'draft'::text AND journal_entry_id IS NULL OR status::text = 'posted'::text AND journal_entry_id IS NOT NULL", name: "expenses_posting_state"
    t.check_constraint "total_kobo > 0", name: "expenses_positive_total"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.bigint "amount_minor", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "invoice_id", null: false
    t.integer "position", null: false
    t.decimal "quantity", precision: 15, scale: 3
    t.bigint "rate_minor"
    t.datetime "updated_at", null: false
    t.index ["invoice_id", "position"], name: "index_invoice_lines_on_invoice_id_and_position", unique: true
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.text "bill_to_address"
    t.string "bill_to_email"
    t.string "bill_to_name"
    t.text "business_address"
    t.string "business_email"
    t.string "business_name"
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.date "due_date"
    t.date "issue_date"
    t.string "status", default: "draft", null: false
    t.bigint "subtotal_minor", default: 0, null: false
    t.bigint "total_minor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["contact_id"], name: "index_invoices_on_contact_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
    t.index ["workspace_id", "status"], name: "index_invoices_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_invoices_on_workspace_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "entry_date", null: false
    t.bigint "reverses_journal_entry_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["reverses_journal_entry_id"], name: "index_journal_entries_on_reverses_journal_entry_id"
    t.index ["reverses_journal_entry_id"], name: "one_reversal_per_entry", unique: true, where: "(reverses_journal_entry_id IS NOT NULL)"
    t.index ["workspace_id", "entry_date"], name: "index_journal_entries_on_workspace_id_and_entry_date"
    t.index ["workspace_id"], name: "index_journal_entries_on_workspace_id"
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "counterparty_id"
    t.string "counterparty_type"
    t.datetime "created_at", null: false
    t.bigint "credit_kobo", default: 0, null: false
    t.bigint "debit_kobo", default: 0, null: false
    t.bigint "journal_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_journal_entry_lines_on_account_id"
    t.index ["counterparty_type", "counterparty_id"], name: "index_journal_entry_lines_on_counterparty"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
    t.check_constraint "debit_kobo > 0 AND credit_kobo = 0 OR credit_kobo > 0 AND debit_kobo = 0", name: "journal_lines_one_positive_side"
  end

  create_table "llm_activities", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.bigint "llm_chat_id", null: false
    t.bigint "turn_user_message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id", "turn_user_message_id", "kind"], name: "index_llm_activities_on_turn_and_kind", unique: true
    t.index ["llm_chat_id"], name: "index_llm_activities_on_llm_chat_id"
  end

  create_table "llm_chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "llm_model_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "workspace_id", null: false
    t.index ["llm_model_id"], name: "index_llm_chats_on_llm_model_id"
    t.index ["uuid"], name: "index_llm_chats_on_uuid", unique: true
    t.index ["workspace_id"], name: "index_llm_chats_on_workspace_id"
  end

  create_table "llm_messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.boolean "internal", default: false, null: false
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_model_id"
    t.bigint "llm_tool_call_id"
    t.bigint "llm_turn_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.datetime "summarized_at"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id", "internal"], name: "index_llm_messages_on_llm_chat_id_and_internal"
    t.index ["llm_chat_id"], name: "index_llm_messages_on_llm_chat_id"
    t.index ["llm_model_id"], name: "index_llm_messages_on_llm_model_id"
    t.index ["llm_tool_call_id"], name: "index_llm_messages_on_llm_tool_call_id"
    t.index ["llm_turn_id"], name: "index_llm_messages_on_llm_turn_id"
    t.index ["role"], name: "index_llm_messages_on_role"
  end

  create_table "llm_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_llm_models_on_family"
    t.index ["modalities"], name: "index_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_llm_models_on_provider"
  end

  create_table "llm_tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "llm_message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.jsonb "trace_output", default: {}, null: false
    t.string "trace_status"
    t.datetime "updated_at", null: false
    t.index ["llm_message_id"], name: "index_llm_tool_calls_on_llm_message_id"
    t.index ["name"], name: "index_llm_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "llm_turns", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "llm_chat_id", null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_message_id", null: false
    t.index ["llm_chat_id", "status"], name: "index_llm_turns_on_llm_chat_id_and_status"
    t.index ["llm_chat_id"], name: "index_llm_turns_on_llm_chat_id"
    t.index ["user_message_id"], name: "index_llm_turns_on_user_message_id", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "proposals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "journal_entry_id"
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_message_id"
    t.string "proposal_type", null: false
    t.string "status", default: "proposed", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.bigint "workspace_id", null: false
    t.index ["journal_entry_id"], name: "index_proposals_on_journal_entry_id"
    t.index ["llm_chat_id", "proposal_type", "version"], name: "index_proposals_on_llm_chat_id_and_proposal_type_and_version"
    t.index ["llm_chat_id"], name: "index_proposals_on_llm_chat_id"
    t.index ["llm_message_id"], name: "index_proposals_on_llm_message_id"
    t.index ["workspace_id", "status"], name: "index_proposals_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_proposals_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.bigint "workspace_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.index ["workspace_id"], name: "index_sessions_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "full_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.datetime "updated_at", null: false
    t.string "workspace_type", default: "personal", null: false
  end

  add_foreign_key "accounts", "workspaces"
  add_foreign_key "contact_roles", "contacts"
  add_foreign_key "contacts", "workspaces"
  add_foreign_key "expense_lines", "accounts"
  add_foreign_key "expense_lines", "expenses"
  add_foreign_key "expenses", "accounts", column: "payment_account_id"
  add_foreign_key "expenses", "contacts", column: "payee_contact_id"
  add_foreign_key "expenses", "journal_entries"
  add_foreign_key "expenses", "workspaces"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoices", "contacts"
  add_foreign_key "invoices", "users"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "journal_entries", "journal_entries", column: "reverses_journal_entry_id"
  add_foreign_key "journal_entries", "workspaces"
  add_foreign_key "journal_entry_lines", "accounts"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "llm_activities", "llm_chats"
  add_foreign_key "llm_chats", "llm_models"
  add_foreign_key "llm_chats", "workspaces"
  add_foreign_key "llm_messages", "llm_chats"
  add_foreign_key "llm_messages", "llm_models"
  add_foreign_key "llm_messages", "llm_tool_calls"
  add_foreign_key "llm_messages", "llm_turns"
  add_foreign_key "llm_tool_calls", "llm_messages"
  add_foreign_key "llm_turns", "llm_chats"
  add_foreign_key "llm_turns", "llm_messages", column: "user_message_id"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "proposals", "journal_entries"
  add_foreign_key "proposals", "llm_chats"
  add_foreign_key "proposals", "llm_messages"
  add_foreign_key "proposals", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "workspaces"
end
