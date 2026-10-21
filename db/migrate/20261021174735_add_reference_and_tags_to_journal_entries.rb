class AddReferenceAndTagsToJournalEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :journal_entries, :reference, :string
    add_column :journal_entries, :tags, :string, array: true, null: false, default: []
    add_index :journal_entries, :tags, using: :gin

    add_column :journal_entry_drafts, :reference, :string
    add_column :journal_entry_drafts, :tags, :string, array: true, null: false, default: []
  end
end
