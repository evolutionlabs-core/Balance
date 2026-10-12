class AddClosedThroughToLedgers < ActiveRecord::Migration[8.1]
  def change
    add_column :ledgers, :closed_through, :date
    add_column :ledgers, :closed_at, :datetime
    add_column :ledgers, :closed_by_id, :bigint

    add_foreign_key :ledgers, :users, column: "closed_by_id"
  end
end
