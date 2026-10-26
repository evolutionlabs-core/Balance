class CreateCreditNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_notes do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :number
      t.date :issued_on, null: false
      t.bigint :amount_minor, null: false
      t.text :reason, null: false
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
  end
end
