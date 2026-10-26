class CreateCreditNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_notes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.string :number
      t.date :issued_on, null: false
      t.string :currency_code, null: false
      t.string :bill_to_name
      t.string :bill_to_email
      t.text :bill_to_address
      t.bigint :subtotal_minor, default: 0, null: false
      t.string :discount_type
      t.decimal :discount_value, precision: 15, scale: 2
      t.bigint :discount_minor, default: 0, null: false
      t.bigint :total_minor, default: 0, null: false
      t.text :notes
      t.bigint :journal_entry_id
      t.bigint :void_journal_entry_id
      t.datetime :voided_at

      t.timestamps
    end
    add_index :credit_notes, [ :workspace_id, :number ], unique: true
    add_index :credit_notes, :journal_entry_id, unique: true
    add_index :credit_notes, :void_journal_entry_id, unique: true
    add_foreign_key :credit_notes, :journal_entries
    add_foreign_key :credit_notes, :journal_entries, column: :void_journal_entry_id

    create_table :credit_note_lines do |t|
      t.references :credit_note, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :account, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 15, scale: 3
      t.bigint :rate_minor
      t.bigint :amount_minor, default: 0, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    create_table :credit_applications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :credit_note, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.bigint :amount_minor, null: false

      t.timestamps
    end
    add_index :credit_applications, [ :credit_note_id, :invoice_id ], unique: true
  end
end
