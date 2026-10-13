class DropLegacyAccounting < ActiveRecord::Migration[8.1]
  def change
    remove_index :expenses, :journal_entry_id, where: "(journal_entry_id IS NOT NULL)"
    remove_foreign_key :expenses, :journal_entries
    remove_column :expenses, :journal_entry_id

    remove_index :proposals, :journal_entry_id
    remove_foreign_key :proposals, :journal_entries
    rename_column :proposals, :journal_entry_id, :ledger_entry_id
    add_index :proposals, :ledger_entry_id
    add_foreign_key :proposals, :ledger_entries

    drop_table :journal_entry_lines do |t|
      t.bigint :account_id, null: false
      t.bigint :counterparty_id
      t.string :counterparty_type
      t.bigint :credit_kobo, default: 0, null: false
      t.bigint :debit_kobo, default: 0, null: false
      t.bigint :journal_entry_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    drop_table :journal_entries do |t|
      t.text :description, null: false
      t.date :entry_date, null: false
      t.bigint :reverses_journal_entry_id
      t.bigint :workspace_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    drop_table :accounts do |t|
      t.string :account_type, null: false
      t.string :base_type, null: false
      t.text :description
      t.string :detail_type, null: false
      t.string :name, null: false
      t.string :role
      t.bigint :workspace_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
