class CreateEntryTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :entry_templates do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :tags, array: true, null: false, default: []
      t.jsonb :lines, null: false, default: []

      t.timestamps
    end
    add_index :entry_templates, [ :workspace_id, :name ], unique: true
  end
end
