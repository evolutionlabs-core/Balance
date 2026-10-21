class AddFiscalYearStartMonthToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :fiscal_year_start_month, :integer, null: false, default: 1
  end
end
