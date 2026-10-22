class AddConversionReferencesToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_reference :invoices, :estimate, null: true, foreign_key: true
    add_reference :invoices, :project, null: true, foreign_key: true
    add_column :invoices, :invoice_number, :string
    add_index :invoices, %i[workspace_id invoice_number], unique: true
  end
end
