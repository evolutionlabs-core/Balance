class AddAccountToInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    add_reference :invoice_lines, :account, null: true, foreign_key: true
    add_reference :invoices, :journal_entry, null: true, foreign_key: true
  end
end
