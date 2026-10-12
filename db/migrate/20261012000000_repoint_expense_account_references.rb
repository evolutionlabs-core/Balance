class RepointExpenseAccountReferences < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :expense_lines, :accounts
    remove_foreign_key :expenses, column: "payment_account_id"

    add_foreign_key :expense_lines, :ledger_accounts, column: "account_id", validate: false
    add_foreign_key :expenses, :ledger_accounts, column: "payment_account_id", validate: false
  end
end
