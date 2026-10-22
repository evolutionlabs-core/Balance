class CreateInvoicePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_payments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.bigint :journal_entry_id
      t.bigint :reverses_invoice_payment_id
      t.bigint :amount_kobo, null: false

      t.timestamps
    end
    add_index :invoice_payments, [ :journal_entry_id, :invoice_id ], unique: true
    add_index :invoice_payments, :journal_entry_id
    add_index :invoice_payments, :reverses_invoice_payment_id, unique: true
    add_foreign_key :invoice_payments, :journal_entries
    add_foreign_key :invoice_payments, :invoice_payments, column: :reverses_invoice_payment_id
  end
end
