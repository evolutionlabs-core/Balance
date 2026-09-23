class AddDefaultSalesAccountToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_reference :workspaces, :default_sales_account, foreign_key: { to_table: :accounts }
  end
end
