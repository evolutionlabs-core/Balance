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

  test "recognizes only its own owner members" do
    workspace = workspaces(:ada_store)
    owner = memberships(:ada_owner).user
    stranger = memberships(:bola_owner).user

    assert workspace.owned_by?(owner)
    assert_not workspace.owned_by?(stranger)
    assert_not workspace.owned_by?(nil)
  end
end
