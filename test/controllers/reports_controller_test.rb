require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @salary = @ledger.accounts.find_by!(name: "Salary")
  end

  test "balance sheet lists every account with its amount and balances" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 500_000)

    get balance_sheet_path

    assert_response :success
    assert_select "body", /Balance sheet/
    assert_select "section[aria-labelledby=assets-heading] span", text: "Cash"
    assert_select "section[aria-labelledby=equity-heading] span", text: "Current earnings (unclosed)"
    assert_select "section[aria-labelledby=equity-heading] span", text: /#{Regexp.escape("₦5,000.00")}/
    assert_select "section[aria-labelledby=assets-heading] span", text: /#{Regexp.escape("₦5,000.00")}/
    assert_select "body", /Balanced — assets equal liabilities plus equity/
  end

  test "income statement shows only the selected month" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary,
      amount_kobo: 300_000, effective_date: Date.current)
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary,
      amount_kobo: 900_000, effective_date: Date.current.prev_month)

    get income_statement_path

    assert_response :success
    assert_select "body", text: /#{Regexp.escape("₦3,000.00")}/, count: 1
    assert_select "body", text: /#{Regexp.escape("₦9,000.00")}/, count: 0
    assert_select "section[aria-labelledby=net-income-heading] p", text: /#{Regexp.escape("₦3,000.00")}/

    get income_statement_path(month: Date.current.prev_month.iso8601)

    assert_response :success
    assert_select "body", text: /#{Regexp.escape("₦9,000.00")}/, count: 1
    assert_select "body", text: /#{Regexp.escape("₦3,000.00")}/, count: 0
    assert_select "nav[aria-label='Statement month'] svg", count: 2
    assert_select "nav[aria-label='Statement month']", { text: /Previous month/, count: 1 }
  end

  test "reports render an empty state when no ledger is provisioned" do
    user = User.create!(full_name: "No Ledger", email_address: "noledger@example.com", password: "supersecret123")
    workspace = Workspace.create!(name: "No Ledger Co", currency_code: "NGN")
    user.memberships.create!(workspace: workspace, role: :owner)
    sign_in_as(user)

    get balance_sheet_path
    assert_response :success
    assert_select "h2", text: "No accounts yet"

    get income_statement_path
    assert_response :success
    assert_select "h2", text: "No accounts yet"
  end

  test "aged receivables shows the tie-out to the control account" do
    get aged_receivables_path

    assert_response :success
    assert_select "h1", /Aged receivables/
    assert_select "#tie-out", /Ties out: Accounts Receivable holds/
  end

  test "aged payables is only for business workspaces" do
    get aged_payables_path

    assert_redirected_to aged_receivables_path
  end
end

class BusinessReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    sign_in_as(users(:three))
  end

  test "aged payables lists open bills by vendor" do
    rent = @ledger.accounts.find_by!(key: "rent")
    vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    bill = @workspace.bills.create!(user: users(:three), vendor: vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: rent.id, description: "Office rent", amount: "750.00" } ])
    assert bill.issue!

    get aged_payables_path

    assert_response :success
    assert_select "tbody th", text: "Lagos Landlords"
    assert_select "#tie-out", /Ties out: Accounts Payable holds ₦750.00/
    assert_select "nav[aria-label=Reports] a", text: "Payables"
  end
end
