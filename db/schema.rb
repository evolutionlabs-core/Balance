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

ActiveRecord::Schema[8.1].define(version: 2026_09_23_120000) do
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

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.string "customer_type", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "active"], name: "index_customers_on_workspace_id_and_active"
    t.index ["workspace_id", "name"], name: "index_customers_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_customers_on_workspace_id"
  end

  create_table "estimate_line_items", force: :cascade do |t|
    t.bigint "amount_minor", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "estimate_id", null: false
    t.integer "position", null: false
    t.decimal "quantity", precision: 15, scale: 3
    t.bigint "rate_minor"
    t.bigint "service_id"
    t.datetime "updated_at", null: false
    t.index ["estimate_id", "position"], name: "index_estimate_line_items_on_estimate_id_and_position", unique: true
    t.index ["estimate_id"], name: "index_estimate_line_items_on_estimate_id"
    t.index ["service_id"], name: "index_estimate_line_items_on_service_id"
  end

  create_table "estimates", force: :cascade do |t|
    t.text "bill_to_address"
    t.string "bill_to_email"
    t.string "bill_to_name"
    t.text "business_address"
    t.string "business_email"
    t.string "business_name"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.bigint "customer_id", null: false
    t.text "notes"
    t.bigint "project_id"
    t.string "status", default: "draft", null: false
    t.bigint "subtotal_minor", default: 0, null: false
    t.bigint "total_minor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["customer_id"], name: "index_estimates_on_customer_id"
    t.index ["project_id"], name: "index_estimates_on_project_id"
    t.index ["user_id"], name: "index_estimates_on_user_id"
    t.index ["workspace_id", "project_id"], name: "index_estimates_on_workspace_id_and_project_id"
    t.index ["workspace_id", "status"], name: "index_estimates_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_estimates_on_workspace_id"
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
  end

  create_table "expenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "journal_entry_id"
    t.text "memo"
    t.bigint "payment_account_id", null: false
    t.date "payment_date", null: false
    t.string "status", default: "draft", null: false
    t.bigint "total_kobo", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["journal_entry_id"], name: "index_expenses_on_journal_entry_id", unique: true, where: "(journal_entry_id IS NOT NULL)"
    t.index ["payment_account_id"], name: "index_expenses_on_payment_account_id"
    t.index ["workspace_id", "payment_date"], name: "index_expenses_on_workspace_id_and_payment_date"
    t.index ["workspace_id", "status"], name: "index_expenses_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_expenses_on_workspace_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "amount_minor", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "invoice_id", null: false
    t.integer "position", null: false
    t.decimal "quantity", precision: 15, scale: 3
    t.bigint "rate_minor"
    t.bigint "service_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_invoice_lines_on_account_id"
    t.index ["invoice_id", "position"], name: "index_invoice_lines_on_invoice_id_and_position", unique: true
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["service_id"], name: "index_invoice_lines_on_service_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.text "bill_to_address"
    t.string "bill_to_email"
    t.string "bill_to_name"
    t.text "business_address"
    t.string "business_email"
    t.string "business_name"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.bigint "customer_id"
    t.date "due_date"
    t.bigint "estimate_id"
    t.string "invoice_number"
    t.date "issue_date"
    t.bigint "journal_entry_id"
    t.bigint "project_id"
    t.string "status", default: "draft", null: false
    t.bigint "subtotal_minor", default: 0, null: false
    t.bigint "total_minor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["estimate_id"], name: "index_invoices_on_estimate_id"
    t.index ["journal_entry_id"], name: "index_invoices_on_journal_entry_id"
    t.index ["project_id"], name: "index_invoices_on_project_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
    t.index ["workspace_id", "invoice_number"], name: "index_invoices_on_workspace_id_and_invoice_number", unique: true
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

  create_table "project_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "internal_note"
    t.integer "position", default: 0, null: false
    t.bigint "project_id", null: false
    t.string "status", default: "todo", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "position"], name: "index_project_tasks_on_project_id_and_position"
    t.index ["project_id"], name: "index_project_tasks_on_project_id"
  end

  create_table "project_time_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.decimal "hours", precision: 8, scale: 2, null: false
    t.text "internal_note"
    t.date "occurred_on", null: false
    t.bigint "project_id", null: false
    t.bigint "project_task_id"
    t.datetime "updated_at", null: false
    t.index ["project_id", "occurred_on"], name: "index_project_time_entries_on_project_id_and_occurred_on"
    t.index ["project_id"], name: "index_project_time_entries_on_project_id"
    t.index ["project_task_id"], name: "index_project_time_entries_on_project_task_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "cost_budget_kobo"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.bigint "customer_id", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["customer_id"], name: "index_projects_on_customer_id"
    t.index ["workspace_id", "customer_id"], name: "index_projects_on_workspace_id_and_customer_id"
    t.index ["workspace_id"], name: "index_projects_on_workspace_id"
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

  create_table "receivable_applications", force: :cascade do |t|
    t.bigint "amount_kobo", null: false
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.bigint "journal_entry_id", null: false
    t.bigint "reverses_receivable_application_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["invoice_id"], name: "index_receivable_applications_on_invoice_id"
    t.index ["journal_entry_id", "invoice_id"], name: "idx_on_journal_entry_id_invoice_id_90d136502d", unique: true
    t.index ["journal_entry_id"], name: "index_receivable_applications_on_journal_entry_id"
    t.index ["reverses_receivable_application_id"], name: "idx_on_reverses_receivable_application_id_0fce615a15", unique: true
    t.index ["workspace_id"], name: "index_receivable_applications_on_workspace_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "default_rate_minor"
    t.text "description"
    t.bigint "income_account_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["income_account_id"], name: "index_services_on_income_account_id"
    t.index ["workspace_id", "name"], name: "index_services_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_services_on_workspace_id"
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
    t.bigint "default_sales_account_id"
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.datetime "updated_at", null: false
    t.string "workspace_type", default: "personal", null: false
    t.index ["default_sales_account_id"], name: "index_workspaces_on_default_sales_account_id"
  end

  add_foreign_key "accounts", "workspaces"
  add_foreign_key "customers", "workspaces"
  add_foreign_key "estimate_line_items", "estimates"
  add_foreign_key "estimate_line_items", "services"
  add_foreign_key "estimates", "customers"
  add_foreign_key "estimates", "projects"
  add_foreign_key "estimates", "users"
  add_foreign_key "estimates", "workspaces"
  add_foreign_key "expense_lines", "accounts"
  add_foreign_key "expense_lines", "expenses"
  add_foreign_key "expenses", "accounts", column: "payment_account_id"
  add_foreign_key "expenses", "journal_entries"
  add_foreign_key "expenses", "workspaces"
  add_foreign_key "invoice_lines", "accounts"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_lines", "services"
  add_foreign_key "invoices", "customers"
  add_foreign_key "invoices", "estimates"
  add_foreign_key "invoices", "journal_entries"
  add_foreign_key "invoices", "projects"
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
  add_foreign_key "project_tasks", "projects"
  add_foreign_key "project_time_entries", "project_tasks"
  add_foreign_key "project_time_entries", "projects"
  add_foreign_key "projects", "customers"
  add_foreign_key "projects", "workspaces"
  add_foreign_key "proposals", "journal_entries"
  add_foreign_key "proposals", "llm_chats"
  add_foreign_key "proposals", "llm_messages"
  add_foreign_key "proposals", "workspaces"
  add_foreign_key "receivable_applications", "invoices"
  add_foreign_key "receivable_applications", "journal_entries"
  add_foreign_key "receivable_applications", "receivable_applications", column: "reverses_receivable_application_id"
  add_foreign_key "receivable_applications", "workspaces"
  add_foreign_key "services", "accounts", column: "income_account_id"
  add_foreign_key "services", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "workspaces"
  add_foreign_key "workspaces", "accounts", column: "default_sales_account_id"
end
