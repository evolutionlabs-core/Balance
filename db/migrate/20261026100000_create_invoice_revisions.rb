class CreateInvoiceRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_revisions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :field_changes, null: false, default: {}

      t.timestamps
    end
  end
end
