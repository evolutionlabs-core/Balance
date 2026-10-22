class AddTermsNotesAndDiscountToInvoices < ActiveRecord::Migration[8.1]
  def change
    change_table :invoices, bulk: true do |t|
      t.string :payment_terms
      t.string :reference
      t.text :notes
      t.text :internal_note
      t.text :payment_instructions
      t.string :discount_type
      t.decimal :discount_value, precision: 15, scale: 2
      t.bigint :discount_minor, default: 0, null: false
    end

    change_table :workspaces, bulk: true do |t|
      t.string :default_payment_terms, default: "net_30", null: false
      t.text :default_invoice_note
      t.text :payment_instructions
    end
  end
end
