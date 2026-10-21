class CreateJournalEntryDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entry_drafts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :posted_entry, foreign_key: { to_table: :journal_entries }, index: { unique: true }
      t.date :effective_date
      t.text :description
      t.jsonb :lines, null: false, default: []

      t.timestamps
    end
  end
end
