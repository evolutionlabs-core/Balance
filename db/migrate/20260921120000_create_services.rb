class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :income_account, null: false, foreign_key: { to_table: :accounts }
      t.string :name, null: false
      t.text :description
      t.bigint :default_rate_minor
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :services, [ :workspace_id, :name ], unique: true
    add_reference :estimate_line_items, :service, foreign_key: true
    add_reference :invoice_lines, :service, foreign_key: true
  end
end
