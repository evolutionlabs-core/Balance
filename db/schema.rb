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

ActiveRecord::Schema[8.1].define(version: 2026_10_19_000200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "base_type", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "created_by", default: "admin", null: false
    t.text "description"
    t.string "key"
    t.bigint "ledger_id", null: false
    t.string "name", null: false
    t.string "normal_balance", null: false
    t.string "subtype", null: false
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_id", "code"], name: "index_accounts_on_ledger_id_and_code", unique: true
    t.index ["ledger_id", "key"], name: "index_accounts_on_ledger_id_and_key", unique: true, where: "(key IS NOT NULL)"
    t.index ["ledger_id", "name"], name: "index_accounts_on_ledger_id_and_name", unique: true
    t.index ["ledger_id"], name: "index_accounts_on_ledger_id"
    t.check_constraint "base_type::text = ANY (ARRAY['asset'::character varying::text, 'liability'::character varying::text, 'equity'::character varying::text, 'income'::character varying::text, 'expense'::character varying::text])", name: "chk_accounts_base_type"
    t.check_constraint "created_by::text = ANY (ARRAY['system'::character varying::text, 'admin'::character varying::text, 'agent'::character varying::text])", name: "chk_accounts_created_by"
    t.check_constraint "normal_balance::text = ANY (ARRAY['debit'::character varying::text, 'credit'::character varying::text])", name: "chk_accounts_normal_balance"
  end

  create_table "bill_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "amount_kobo", null: false
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_bill_lines_on_account_id"
    t.index ["bill_id", "position"], name: "index_bill_lines_on_bill_id_and_position", unique: true
    t.index ["bill_id"], name: "index_bill_lines_on_bill_id"
  end

  create_table "bill_payments", force: :cascade do |t|
    t.bigint "amount_kobo", null: false
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.bigint "journal_entry_id"
    t.bigint "reverses_bill_payment_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["bill_id"], name: "index_bill_payments_on_bill_id"
    t.index ["journal_entry_id", "bill_id"], name: "index_bill_payments_on_journal_entry_id_and_bill_id", unique: true
    t.index ["journal_entry_id"], name: "index_bill_payments_on_journal_entry_id"
    t.index ["reverses_bill_payment_id"], name: "index_bill_payments_on_reverses_bill_payment_id", unique: true
    t.index ["workspace_id"], name: "index_bill_payments_on_workspace_id"
  end

  create_table "bills", force: :cascade do |t|
    t.date "bill_date"
    t.string "bill_number"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.date "due_date"
    t.text "notes"
    t.string "status", default: "draft", null: false
    t.bigint "total_kobo", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "vendor_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_bills_on_user_id"
    t.index ["vendor_id", "bill_number"], name: "index_bills_on_vendor_id_and_bill_number", unique: true, where: "(bill_number IS NOT NULL)"
    t.index ["vendor_id"], name: "index_bills_on_vendor_id"
    t.index ["workspace_id", "status"], name: "index_bills_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_bills_on_workspace_id"
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
    t.datetime "client_decided_at"
    t.string "client_decision"
    t.jsonb "client_review_snapshot"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.bigint "customer_id", null: false
    t.integer "lock_version", default: 0, null: false
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
    t.text "memo"
    t.bigint "payment_account_id", null: false
    t.date "payment_date", null: false
    t.string "status", default: "draft", null: false
    t.bigint "total_kobo", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
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

  create_table "invoice_payments", force: :cascade do |t|
    t.bigint "amount_kobo", null: false
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.bigint "journal_entry_id"
    t.bigint "reverses_invoice_payment_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["invoice_id"], name: "index_invoice_payments_on_invoice_id"
    t.index ["journal_entry_id", "invoice_id"], name: "index_invoice_payments_on_journal_entry_id_and_invoice_id", unique: true
    t.index ["journal_entry_id"], name: "index_invoice_payments_on_journal_entry_id"
    t.index ["reverses_invoice_payment_id"], name: "index_invoice_payments_on_reverses_invoice_payment_id", unique: true
    t.index ["workspace_id"], name: "index_invoice_payments_on_workspace_id"
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
    t.bigint "project_id"
    t.string "status", default: "draft", null: false
    t.bigint "subtotal_minor", default: 0, null: false
    t.bigint "total_minor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["estimate_id"], name: "index_invoices_on_estimate_id"
    t.index ["project_id"], name: "index_invoices_on_project_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
    t.index ["workspace_id", "invoice_number"], name: "index_invoices_on_workspace_id_and_invoice_number", unique: true
    t.index ["workspace_id", "status"], name: "index_invoices_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_invoices_on_workspace_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "effective_date", null: false
    t.bigint "ledger_id", null: false
    t.integer "number", null: false
    t.bigint "posted_by_id"
    t.bigint "reverses_entry_id"
    t.bigint "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["ledger_id", "effective_date"], name: "index_journal_entries_on_ledger_id_and_effective_date"
    t.index ["ledger_id", "number"], name: "index_journal_entries_on_ledger_id_and_number", unique: true
    t.index ["ledger_id", "source_type", "source_id", "action"], name: "idx_journal_entries_unique_source_effect", unique: true, where: "((source_type IS NOT NULL) AND (source_id IS NOT NULL) AND (action IS NOT NULL))"
    t.index ["ledger_id"], name: "index_journal_entries_on_ledger_id"
    t.index ["posted_by_id"], name: "index_journal_entries_on_posted_by_id"
    t.index ["reverses_entry_id"], name: "index_journal_entries_on_reverses_entry_id", unique: true
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "credit", default: 0, null: false
    t.bigint "customer_id"
    t.bigint "debit", default: 0, null: false
    t.bigint "journal_entry_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id"
    t.index ["account_id"], name: "index_journal_entry_lines_on_account_id"
    t.index ["customer_id"], name: "index_journal_entry_lines_on_customer_id"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
    t.index ["vendor_id"], name: "index_journal_entry_lines_on_vendor_id"
    t.check_constraint "customer_id IS NULL OR vendor_id IS NULL", name: "chk_journal_entry_lines_one_counterparty"
    t.check_constraint "debit > 0 AND credit = 0 OR credit > 0 AND debit = 0", name: "chk_journal_entry_lines_one_sided_non_zero"
  end

  create_table "ledgers", force: :cascade do |t|
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.date "closed_through"
    t.datetime "created_at", null: false
    t.string "currency_code", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_ledgers_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_ledgers_on_workspace_id", unique: true
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
    t.boolean "cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "ruby_llm_model_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "workspace_id", null: false
    t.index ["ruby_llm_model_id"], name: "index_llm_chats_on_ruby_llm_model_id"
    t.index ["uuid"], name: "index_llm_chats_on_uuid", unique: true
    t.index ["workspace_id"], name: "index_llm_chats_on_workspace_id"
  end

  create_table "llm_messages", force: :cascade do |t|
    t.string "cache_ttl"
    t.boolean "cache_until_here", default: false, null: false
    t.jsonb "citations"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "finish_reason"
    t.boolean "internal", default: false, null: false
    t.bigint "llm_chat_id", null: false
    t.bigint "llm_turn_id"
    t.jsonb "raw_content"
    t.jsonb "raw_reasoning"
    t.string "role", null: false
    t.jsonb "server_tool_calls"
    t.datetime "summarized_at"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.datetime "updated_at", null: false
    t.index ["llm_chat_id", "internal"], name: "index_llm_messages_on_llm_chat_id_and_internal"
    t.index ["llm_chat_id"], name: "index_llm_messages_on_llm_chat_id"
    t.index ["llm_turn_id"], name: "index_llm_messages_on_llm_turn_id"
    t.index ["role"], name: "index_llm_messages_on_role"
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

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "batch_protocol"
    t.jsonb "chat_ids", default: []
    t.string "chat_type"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "provider_batch_id", null: false
    t.string "raw_status"
    t.jsonb "reported_cost"
    t.jsonb "request_counts"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_mcp_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "key", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ruby_llm_mcp_credentials_on_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_mcp_credentials_on_owner"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
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
    t.datetime "unlisted_at"
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ruby_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["modalities"], name: "index_ruby_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_provider_files", force: :cascade do |t|
    t.string "account", null: false
    t.string "blob_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "file_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_key", "provider", "account"], name: "index_ruby_llm_provider_files_uniqueness", unique: true
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "approval"
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.jsonb "mcp_result"
    t.jsonb "mcp_state"
    t.bigint "message_id", null: false
    t.string "message_type", null: false
    t.string "name", null: false
    t.boolean "remote", default: false, null: false
    t.bigint "result_id"
    t.string "result_type"
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.jsonb "trace_output", default: {}, null: false
    t.string "trace_status"
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.integer "cache_read_tokens"
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.integer "cache_write_tokens"
    t.bigint "chat_id"
    t.string "chat_type"
    t.datetime "created_at", null: false
    t.decimal "input_cost", precision: 16, scale: 10
    t.integer "input_tokens"
    t.bigint "message_id"
    t.string "message_type"
    t.string "model", null: false
    t.string "operation", null: false
    t.decimal "output_cost", precision: 16, scale: 10
    t.integer "output_tokens"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "provider", null: false
    t.jsonb "server_tool_use"
    t.string "status", null: false
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.integer "thinking_tokens"
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_usages_on_owner_type_and_owner_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation::text = ANY (ARRAY['chat'::text, 'embedding'::text, 'moderation'::text, 'image'::text, 'speech'::text, 'transcription'::text, 'ocr'::text, 'rerank'::text, 'judgment'::text, 'video'::text, 'research'::text])"
    t.check_constraint "status::text = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text])"
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

  create_table "vendors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_vendors_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_vendors_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "currency_code", default: "NGN", null: false
    t.bigint "default_deposit_account_id"
    t.bigint "default_sales_account_id"
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.datetime "updated_at", null: false
    t.string "workspace_type", default: "personal", null: false
    t.index ["default_deposit_account_id"], name: "index_workspaces_on_default_deposit_account_id"
    t.index ["default_sales_account_id"], name: "index_workspaces_on_default_sales_account_id"
  end

  add_foreign_key "accounts", "ledgers"
  add_foreign_key "bill_lines", "accounts"
  add_foreign_key "bill_lines", "bills"
  add_foreign_key "bill_payments", "bill_payments", column: "reverses_bill_payment_id"
  add_foreign_key "bill_payments", "bills"
  add_foreign_key "bill_payments", "journal_entries"
  add_foreign_key "bill_payments", "workspaces"
  add_foreign_key "bills", "users"
  add_foreign_key "bills", "vendors"
  add_foreign_key "bills", "workspaces"
  add_foreign_key "customers", "workspaces"
  add_foreign_key "estimate_line_items", "estimates"
  add_foreign_key "estimate_line_items", "services"
  add_foreign_key "estimates", "customers"
  add_foreign_key "estimates", "projects"
  add_foreign_key "estimates", "users"
  add_foreign_key "estimates", "workspaces"
  add_foreign_key "expense_lines", "accounts", validate: false
  add_foreign_key "expense_lines", "expenses"
  add_foreign_key "expenses", "accounts", column: "payment_account_id", validate: false
  add_foreign_key "expenses", "workspaces"
  add_foreign_key "invoice_lines", "accounts"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_lines", "services"
  add_foreign_key "invoice_payments", "invoice_payments", column: "reverses_invoice_payment_id"
  add_foreign_key "invoice_payments", "invoices"
  add_foreign_key "invoice_payments", "journal_entries"
  add_foreign_key "invoice_payments", "workspaces"
  add_foreign_key "invoices", "customers"
  add_foreign_key "invoices", "estimates"
  add_foreign_key "invoices", "projects"
  add_foreign_key "invoices", "users"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "journal_entries", "journal_entries", column: "reverses_entry_id"
  add_foreign_key "journal_entries", "ledgers"
  add_foreign_key "journal_entries", "users", column: "posted_by_id"
  add_foreign_key "journal_entry_lines", "accounts"
  add_foreign_key "journal_entry_lines", "customers"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "journal_entry_lines", "vendors"
  add_foreign_key "ledgers", "users", column: "closed_by_id"
  add_foreign_key "ledgers", "workspaces"
  add_foreign_key "llm_activities", "llm_chats"
  add_foreign_key "llm_chats", "ruby_llm_models"
  add_foreign_key "llm_chats", "workspaces"
  add_foreign_key "llm_messages", "llm_chats"
  add_foreign_key "llm_messages", "llm_turns"
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
  add_foreign_key "services", "accounts", column: "income_account_id"
  add_foreign_key "services", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "workspaces"
  add_foreign_key "vendors", "workspaces"
  add_foreign_key "workspaces", "accounts", column: "default_deposit_account_id"
  add_foreign_key "workspaces", "accounts", column: "default_sales_account_id"
end
