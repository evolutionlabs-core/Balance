class MakeReceivableEntryStagingNullable < ActiveRecord::Migration[8.1]
  # Receivable applications are persisted before payment posting so the
  # engine command can source on the application row; the ledger entry id is
  # stamped after Engine.post succeeds inside the recorder's transaction.
  def change
    change_column_null :receivable_applications, :ledger_entry_id, true
  end
end
