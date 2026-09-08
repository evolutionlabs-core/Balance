class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :invoice_number
      t.date :issue_date
      t.date :due_date
      t.string :currency_code, null: false, default: "NGN"
      t.bigint :subtotal_minor, null: false, default: 0
      t.bigint :total_minor, null: false, default: 0
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :invoices, [ :workspace_id, :invoice_number ], unique: true
    add_index :invoices, [ :workspace_id, :status ]

    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.text :description
      t.decimal :quantity, precision: 15, scale: 3
      t.bigint :rate_minor
      t.bigint :amount_minor, null: false, default: 0
      t.integer :position, null: false

      t.timestamps
    end
    add_index :invoice_lines, [ :invoice_id, :position ], unique: true
  end
end
