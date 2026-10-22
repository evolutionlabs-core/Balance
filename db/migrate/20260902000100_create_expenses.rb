class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :payment_account_id, null: false
      t.date :payment_date, null: false
      t.string :status, null: false, default: "draft"
      t.text :memo
      t.bigint :total_kobo, null: false

      t.timestamps
    end
    add_index :expenses, [ :workspace_id, :payment_date ]
    add_index :expenses, [ :workspace_id, :status ]
    add_index :expenses, :payment_account_id

    create_table :expense_lines do |t|
      t.references :expense, null: false, foreign_key: true
      t.bigint :account_id, null: false
      t.text :description, null: false
      t.bigint :amount_kobo, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :expense_lines, [ :expense_id, :position ], unique: true
    add_index :expense_lines, :account_id
  end
end
