class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :customer_type, null: false
      t.string :email
      t.string :phone
      t.text :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :customers, [ :workspace_id, :name ]
    add_index :customers, [ :workspace_id, :active ]

    add_reference :invoices, :customer, foreign_key: { to_table: :customers }
  end
end
