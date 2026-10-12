class AddDescriptionToLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_entries, :description, :text
  end
end
