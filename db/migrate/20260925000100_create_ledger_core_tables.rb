class CreateLedgerCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ledgers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :currency_code, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :ledgers, [ :workspace_id, :name ], unique: true

    create_table :ledger_accounts do |t|
      t.references :ledger, null: false, foreign_key: true
      t.string :name, null: false
      t.string :base_type, null: false
      t.string :normal_balance, null: false
      t.string :code, null: false
      t.string :subtype, null: false
      t.boolean :system, null: false, default: false
      t.boolean :active, null: false, default: true
      t.string :created_by, null: false, default: "admin"
      t.text :description

      t.timestamps
    end
    add_index :ledger_accounts, [ :ledger_id, :name ], unique: true
    add_index :ledger_accounts, [ :ledger_id, :code ], unique: true
    add_check_constraint :ledger_accounts, "base_type::text = ANY (ARRAY['asset'::character varying::text, 'liability'::character varying::text, 'equity'::character varying::text, 'income'::character varying::text, 'expense'::character varying::text])", name: "chk_ledger_accounts_base_type"
    add_check_constraint :ledger_accounts, "normal_balance::text = ANY (ARRAY['debit'::character varying::text, 'credit'::character varying::text])", name: "chk_ledger_accounts_normal_balance"
    add_check_constraint :ledger_accounts, "created_by::text = ANY (ARRAY['system'::character varying::text, 'admin'::character varying::text, 'agent'::character varying::text])", name: "chk_ledger_accounts_created_by"

    create_table :ledger_entries do |t|
      t.references :ledger, null: false, foreign_key: true
      t.date :effective_date, null: false
      t.string :source_type
      t.bigint :source_id
      t.string :action

      t.timestamps
    end
    add_index :ledger_entries, [ :ledger_id, :effective_date ]
    add_index :ledger_entries,
      [ :ledger_id, :source_type, :source_id, :action ],
      unique: true,
      name: "idx_ledger_entries_unique_source_effect",
      where: "source_type IS NOT NULL AND source_id IS NOT NULL AND action IS NOT NULL"

    create_table :ledger_lines do |t|
      t.references :ledger_entry, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true
      t.decimal :debit, precision: 19, scale: 4, null: false, default: 0
      t.decimal :credit, precision: 19, scale: 4, null: false, default: 0

      t.timestamps
    end
    add_check_constraint :ledger_lines,
      "(debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)",
      name: "chk_ledger_lines_one_sided_non_zero"

    create_table :rules do |t|
      t.string :name, null: false
      t.references :ledger, null: true, foreign_key: true
      t.string :source_type
      t.string :action
      t.jsonb :conditions, null: false, default: []
      t.string :severity, null: false
      t.text :message, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :rules, [ :active, :ledger_id, :source_type, :action ], name: "idx_rules_fetch"
    add_check_constraint :rules,
      "severity::text = ANY (ARRAY['block'::character varying::text, 'require_approval'::character varying::text, 'warn'::character varying::text])",
      name: "chk_rules_severity"
  end
end
