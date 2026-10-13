require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income = @ledger.ledger_accounts.find_by!(name: "Other Income")
  end

  test "default sales account must be an income ledger account in the workspace" do
    receivable = @ledger.ledger_accounts.find_by!(name: "Accounts Receivable")
    foreign = workspaces(:bola_shop).provision_ledger!(template: "standard_sme").ledger_accounts.find_by!(name: "Sales")

    assert_not @workspace.update(default_sales_ledger_account: foreign)
    assert_not @workspace.update(default_sales_ledger_account: receivable)
    assert @workspace.update(default_sales_ledger_account: @income)
    assert @workspace.update(default_sales_ledger_account: nil)
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
