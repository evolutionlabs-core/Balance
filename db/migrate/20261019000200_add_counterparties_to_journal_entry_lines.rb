class AddCounterpartiesToJournalEntryLines < ActiveRecord::Migration[8.1]
  def change
    add_reference :journal_entry_lines, :customer, foreign_key: true
    add_reference :journal_entry_lines, :vendor, foreign_key: true
    add_check_constraint :journal_entry_lines, "customer_id IS NULL OR vendor_id IS NULL",
      name: "chk_journal_entry_lines_one_counterparty"
  end
end
