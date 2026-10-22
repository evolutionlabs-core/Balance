require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
  end

  test "default sales account must be an income account in the workspace" do
    receivable = @ledger.accounts.find_by!(name: "Accounts Receivable")
    foreign = provision_business_ledger!(workspaces(:bola_shop)).accounts.find_by!(name: "Sales")

    assert_not @workspace.update(default_sales_account: foreign)
    assert_not @workspace.update(default_sales_account: receivable)
    assert @workspace.update(default_sales_account: @income)
    assert @workspace.update(default_sales_account: nil)
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
