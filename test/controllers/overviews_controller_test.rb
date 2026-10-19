require "test_helper"

class OverviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows period totals reflecting recorded entries" do
    ledger = @workspace.provision_ledger!
    cash = ledger.accounts.find_by!(name: "Cash")
    income = ledger.accounts.find_by!(name: "Salary")
    rent = ledger.accounts.find_by!(name: "Groceries")

    post_journal_entry!(@workspace, debit_account: cash, credit_account: income, amount_kobo: 500_00)
    post_journal_entry!(@workspace, debit_account: rent, credit_account: cash, amount_kobo: 200_00)

    get overview_path
    assert_response :success
    assert_select "body", /#{Regexp.escape("₦500.00")}/
    assert_select "body", /#{Regexp.escape("₦200.00")}/
    assert_select "body", /#{Regexp.escape("₦300.00")}/
    assert_select "#position-heading + p", text: /As of/
    assert_select "section[aria-labelledby=position-heading] dt", text: "Assets"
    assert_select "section[aria-labelledby=position-heading] dt", text: "Net worth"
    assert_select "section[aria-labelledby=position-heading] dd", text: "300.00", minimum: 2
  end

  test "shows charts without a separate empty state when there are no journal entries" do
    get overview_path
    assert_response :success
    assert_select "p", text: "No income or expenses recorded in this period.", count: 0
    assert_select "section[aria-labelledby=performance-heading] [role=img]", count: 2
    assert_select "#recent_feed", count: 0
  end

  test "shows a net loss as a red amount without a minus sign" do
    ledger = @workspace.provision_ledger!
    groceries = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(@workspace, debit_account: groceries, credit_account: ledger.accounts.find_by!(name: "Cash"), amount_kobo: 34_00)

    get overview_path

    assert_select "p", text: "Net loss"
    assert_select "p.text-red-700", text: "₦34.00"
    assert_select "body", text: /-₦34.00/, count: 0
  end

  test "the reports section starts closed away from the reports" do
    get overview_path

    assert_select "nav[aria-label=Primary] details:not([open]) summary", text: "Reports"
  end
end
