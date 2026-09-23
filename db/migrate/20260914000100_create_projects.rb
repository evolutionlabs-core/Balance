class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.bigint :cost_budget_kobo
      t.string :currency_code, null: false, default: "NGN"

      t.timestamps
    end
    add_index :projects, [ :workspace_id, :customer_id ]

    create_table :project_tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "todo"
      t.integer :position, null: false, default: 0
      t.text :internal_note

      t.timestamps
    end
    add_index :project_tasks, [ :project_id, :position ]

    create_table :project_time_entries do |t|
      t.references :project, null: false, foreign_key: true
      t.references :project_task, foreign_key: true
      t.date :occurred_on, null: false
      t.decimal :hours, precision: 8, scale: 2, null: false
      t.text :description, null: false
      t.text :internal_note

      t.timestamps
    end
    add_index :project_time_entries, [ :project_id, :occurred_on ]

    create_table :estimates do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.string :currency_code, null: false, default: "NGN"
      t.string :bill_to_name
      t.string :bill_to_email
      t.text :bill_to_address
      t.string :business_name
      t.string :business_email
      t.text :business_address
      t.text :notes
      t.bigint :subtotal_minor, null: false, default: 0
      t.bigint :total_minor, null: false, default: 0

      t.timestamps
    end
    add_index :estimates, [ :workspace_id, :project_id ]
    add_index :estimates, [ :workspace_id, :status ]

    create_table :estimate_line_items do |t|
      t.references :estimate, null: false, foreign_key: true
      t.text :description
      t.decimal :quantity, precision: 15, scale: 3
      t.bigint :rate_minor
      t.bigint :amount_minor, null: false, default: 0
      t.integer :position, null: false

      t.timestamps
    end
    add_index :estimate_line_items, [ :estimate_id, :position ], unique: true
  end
end
