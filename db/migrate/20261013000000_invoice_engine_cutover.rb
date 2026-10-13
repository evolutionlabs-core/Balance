class InvoiceEngineCutover < ActiveRecord::Migration[8.1]
  def change
    # Pre-production cutover: legacy journal-entry invoice data cannot be
    # remapped onto ledger records, so it starts clean.
    execute "DELETE FROM receivable_applications"
    execute "DELETE FROM invoice_lines"
    execute "DELETE FROM invoices"
    execute "UPDATE estimate_line_items SET service_id = NULL"
    execute "DELETE FROM services"

    remove_foreign_key :invoices, :journal_entries
    remove_column :invoices, :journal_entry_id

    rename_column :invoice_lines, :account_id, :ledger_account_id
    remove_foreign_key :invoice_lines, :accounts
    add_foreign_key :invoice_lines, :ledger_accounts

    remove_foreign_key :services, :accounts
    rename_column :services, :income_account_id, :income_ledger_account_id
    add_foreign_key :services, :ledger_accounts, column: "income_ledger_account_id"

    remove_foreign_key :workspaces, column: "default_sales_account_id"
    rename_column :workspaces, :default_sales_account_id, :default_sales_ledger_account_id
    execute "UPDATE workspaces SET default_sales_ledger_account_id = NULL"
    add_foreign_key :workspaces, :ledger_accounts, column: "default_sales_ledger_account_id"

    remove_foreign_key :receivable_applications, :journal_entries
    rename_column :receivable_applications, :journal_entry_id, :ledger_entry_id
    change_column_null :receivable_applications, :ledger_entry_id, true
    add_foreign_key :receivable_applications, :ledger_entries
  end
end
