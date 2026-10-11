class CreateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :rules do |t|
      t.string :name, null: false
      t.references :ledger, null: true, foreign_key: true
      t.string :source_type
      t.string :action
      t.jsonb :conditions, null: false, default: []
      t.string :severity, null: false
      t.text :message, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :rules, [ :active, :ledger_id, :source_type, :action ], name: "idx_rules_fetch"
    add_check_constraint :rules,
      "severity IN ('block', 'require_approval', 'warn')",
      name: "chk_rules_severity"
  end
end
