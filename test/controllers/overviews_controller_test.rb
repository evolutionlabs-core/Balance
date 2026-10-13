require "test_helper"

class OverviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows period totals reflecting recorded entries" do
    ledger = @workspace.provision_ledger!(template: "personal_finance")
    cash = ledger.ledger_accounts.find_by!(name: "Cash")
    income = ledger.ledger_accounts.find_by!(name: "Salary")
    rent = ledger.ledger_accounts.find_by!(name: "Groceries")

    post_ledger_entry!(@workspace, debit_ledger_account: cash, credit_ledger_account: income, amount_kobo: 500_00)
    post_ledger_entry!(@workspace, debit_ledger_account: rent, credit_ledger_account: cash, amount_kobo: 200_00)

    get overview_path
    assert_response :success
    assert_select "body", /#{Regexp.escape("₦500.00")}/
    assert_select "body", /#{Regexp.escape("₦200.00")}/
    assert_select "body", /#{Regexp.escape("₦300.00")}/
    assert_select "[role=img][aria-label*='Assets, liabilities, and equity']", count: 1
    assert_select "#position-heading + p", text: /Balances as of/
    assert_select "details summary", text: /Assets/, count: 1
  end

  test "shows charts without a separate empty state when there are no ledger entries" do
    get overview_path
    assert_response :success
    assert_select "p", text: "No income or expenses recorded in this period.", count: 0
    assert_select "section[aria-labelledby=performance-heading] [role=img]", count: 2
    assert_select "#recent_feed", count: 0
  end
end
