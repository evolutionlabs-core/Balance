class UseIncomeBaseTypeOnLedgerAccounts < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :ledger_accounts, name: "chk_ledger_accounts_base_type"
    add_check_constraint :ledger_accounts,
      "base_type IN ('asset', 'liability', 'equity', 'income', 'expense')",
      name: "chk_ledger_accounts_base_type"
  end

  def down
    remove_check_constraint :ledger_accounts, name: "chk_ledger_accounts_base_type"
    add_check_constraint :ledger_accounts,
      "base_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')",
      name: "chk_ledger_accounts_base_type"
  end
end
