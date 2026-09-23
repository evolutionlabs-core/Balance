require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "default sales account must be income owned by the workspace" do
    workspace = workspaces(:ada_store)
    foreign = Account.for_role!(workspaces(:bola_shop), :uncategorized_income)
    assert_not workspace.update(default_sales_account: foreign)
    assert_not workspace.update(default_sales_account: Account.for_role!(workspace, :receivable))
    assert workspace.update(default_sales_account: Account.for_role!(workspace, :uncategorized_income))
    assert workspace.update(default_sales_account: nil)
  end
end
