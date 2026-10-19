class AttachLedgerForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_reference :workspaces, :default_sales_account, foreign_key: { to_table: :accounts }

    add_foreign_key :invoice_lines, :accounts
    add_foreign_key :expense_lines, :accounts, column: :account_id, validate: false
    add_foreign_key :expenses, :accounts, column: :payment_account_id, validate: false
    add_foreign_key :services, :accounts, column: :income_account_id
    add_foreign_key :proposals, :journal_entries
  end
end
