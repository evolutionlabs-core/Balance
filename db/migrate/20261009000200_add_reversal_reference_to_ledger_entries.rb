class AddReversalReferenceToLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :ledger_entries, :reverses_ledger_entry, foreign_key: { to_table: :ledger_entries }
  end
end
