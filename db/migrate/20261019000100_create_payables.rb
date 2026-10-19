class CreatePayables < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.text :address
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :vendors, [ :workspace_id, :name ]

    create_table :bills do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: true
      t.string :bill_number
      t.date :bill_date
      t.date :due_date
      t.string :currency_code, null: false, default: "NGN"
      t.bigint :total_kobo, null: false, default: 0
      t.string :status, null: false, default: "draft"
      t.text :notes

      t.timestamps
    end
    add_index :bills, [ :workspace_id, :status ]
    add_index :bills, [ :vendor_id, :bill_number ], unique: true, where: "bill_number IS NOT NULL"

    create_table :bill_lines do |t|
      t.references :bill, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.text :description, null: false
      t.bigint :amount_kobo, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :bill_lines, [ :bill_id, :position ], unique: true

    create_table :bill_payments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.bigint :journal_entry_id
      t.bigint :reverses_bill_payment_id
      t.bigint :amount_kobo, null: false

      t.timestamps
    end
    add_index :bill_payments, [ :journal_entry_id, :bill_id ], unique: true
    add_index :bill_payments, :journal_entry_id
    add_index :bill_payments, :reverses_bill_payment_id, unique: true
    add_foreign_key :bill_payments, :journal_entries
    add_foreign_key :bill_payments, :bill_payments, column: :reverses_bill_payment_id

    # Ledgers provisioned before the catalog marked payables as a system account.
    reversible do |direction|
      direction.up { execute "UPDATE accounts SET system = TRUE WHERE key = 'accounts_payable'" }
    end
  end
end
