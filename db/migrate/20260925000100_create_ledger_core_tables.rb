class CreateLedgerCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ledgers do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :currency_code, null: false
      t.string :status, null: false, default: "active"
      t.date :closed_through
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users }, index: false

      t.timestamps
    end
    add_index :ledgers, [ :workspace_id, :name ], unique: true

    create_table :accounts do |t|
      t.references :ledger, null: false, foreign_key: true
      t.string :key
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
    add_index :accounts, [ :ledger_id, :name ], unique: true
    add_index :accounts, [ :ledger_id, :code ], unique: true
    add_index :accounts, [ :ledger_id, :key ], unique: true, where: "key IS NOT NULL"
    add_check_constraint :accounts, "base_type::text = ANY (ARRAY['asset'::character varying::text, 'liability'::character varying::text, 'equity'::character varying::text, 'income'::character varying::text, 'expense'::character varying::text])", name: "chk_accounts_base_type"
    add_check_constraint :accounts, "normal_balance::text = ANY (ARRAY['debit'::character varying::text, 'credit'::character varying::text])", name: "chk_accounts_normal_balance"
    add_check_constraint :accounts, "created_by::text = ANY (ARRAY['system'::character varying::text, 'admin'::character varying::text, 'agent'::character varying::text])", name: "chk_accounts_created_by"

    create_table :journal_entries do |t|
      t.references :ledger, null: false, foreign_key: true
      t.integer :number, null: false
      t.date :effective_date, null: false
      t.text :description
      t.string :source_type
      t.bigint :source_id
      t.string :action
      t.references :reverses_entry, foreign_key: { to_table: :journal_entries }, index: { unique: true }
      t.references :posted_by, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :journal_entries, [ :ledger_id, :number ], unique: true
    add_index :journal_entries, [ :ledger_id, :effective_date ]
    add_index :journal_entries,
      [ :ledger_id, :source_type, :source_id, :action ],
      unique: true,
      name: "idx_journal_entries_unique_source_effect",
      where: "source_type IS NOT NULL AND source_id IS NOT NULL AND action IS NOT NULL"

    create_table :journal_entry_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.bigint :debit, null: false, default: 0
      t.bigint :credit, null: false, default: 0

      t.timestamps
    end
    add_check_constraint :journal_entry_lines,
      "(debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)",
      name: "chk_journal_entry_lines_one_sided_non_zero"

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
      "severity::text = ANY (ARRAY['block'::character varying::text, 'warn'::character varying::text])",
      name: "chk_rules_severity"
  end
end
