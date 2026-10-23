class BackfillDefaultSalesAccounts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE workspaces
      SET default_sales_account_id = accounts.id
      FROM ledgers
      JOIN accounts ON accounts.ledger_id = ledgers.id
      WHERE ledgers.workspace_id = workspaces.id
        AND workspaces.default_sales_account_id IS NULL
        AND accounts.key = CASE workspaces.workspace_type WHEN 'business' THEN 'sales' ELSE 'other_income' END
    SQL
  end

  def down
  end
end
