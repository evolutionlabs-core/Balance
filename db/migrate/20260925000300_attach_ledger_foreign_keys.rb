class AttachLedgerForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_reference :workspaces, :default_sales_ledger_account, foreign_key: { to_table: :ledger_accounts }

    add_foreign_key :invoice_lines, :ledger_accounts
    add_foreign_key :expense_lines, :ledger_accounts, column: :account_id, validate: false
    add_foreign_key :expenses, :ledger_accounts, column: :payment_account_id, validate: false
    add_foreign_key :services, :ledger_accounts, column: :income_ledger_account_id
    add_foreign_key :proposals, :ledger_entries
  end
end
