class AddInvoicePartyDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :address, :text

    add_column :workspaces, :address, :text

    change_table :invoices, bulk: true do |t|
      t.string :business_name
      t.string :business_email
      t.text :business_address
      t.string :bill_to_name
      t.string :bill_to_email
      t.text :bill_to_address
    end
  end
end
