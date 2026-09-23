class CreateReceivableApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :receivable_applications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.references :journal_entry, null: false, foreign_key: true
      t.references :reverses_receivable_application,
        foreign_key: { to_table: :receivable_applications },
        index: { unique: true }
      t.bigint :amount_kobo, null: false

      t.timestamps
    end

    add_index :receivable_applications, [ :journal_entry_id, :invoice_id ], unique: true
  end
end
