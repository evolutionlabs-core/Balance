class ReplaceContactsWithCustomers < ActiveRecord::Migration[8.1]
  def up
    execute("ALTER TABLE expense_lines DISABLE TRIGGER USER")
    execute("ALTER TABLE expenses DISABLE TRIGGER USER")
    execute("DELETE FROM expense_lines")
    execute("DELETE FROM expenses")
    execute("ALTER TABLE expenses ENABLE TRIGGER USER")
    execute("ALTER TABLE expense_lines ENABLE TRIGGER USER")
    execute("DELETE FROM invoice_lines")
    execute("DELETE FROM invoices")
    execute("DELETE FROM contact_roles")
    execute("DELETE FROM contacts")

    remove_index :expenses,
      name: "index_expenses_for_transaction_duplicate_detection",
      if_exists: true
    remove_reference :expenses, :payee_contact,
      foreign_key: { to_table: :contacts }, index: false

    remove_reference :invoices, :contact, foreign_key: true

    drop_table :contact_roles
    drop_table :contacts

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

  def down
    remove_reference :invoices, :customer, foreign_key: true
    drop_table :customers

    create_table :contacts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :contact_kind, null: false
      t.string :email
      t.string :phone
      t.text :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :contacts, [ :workspace_id, :name ]
    add_index :contacts, [ :workspace_id, :active ]

    create_table :contact_roles do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :contact_roles, [ :contact_id, :role ], unique: true

    add_reference :invoices, :contact, foreign_key: true
    add_reference :expenses, :payee_contact, foreign_key: { to_table: :contacts }
    add_index :expenses,
      [ :workspace_id, :payee_contact_id, :payment_date, :total_kobo ],
      name: "index_expenses_for_transaction_duplicate_detection"
  end
end
