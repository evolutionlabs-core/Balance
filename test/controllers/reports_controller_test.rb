require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @salary = @ledger.accounts.find_by!(name: "Salary")
  end

  test "balance sheet is a classified statement with a comparative column" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 500_000)

    get balance_sheet_path

    assert_response :success
    assert_select "#statement-heading", "Balance Sheet"
    assert_select "thead th", text: Date.current.strftime("%b %-d, %Y")
    assert_select "thead th", text: (Date.current.beginning_of_month - 1).strftime("%b %-d, %Y")
    assert_select "tbody th", text: "Cash and short-term assets"
    assert_select "tbody th", text: /Cash\z/
    assert_select "tbody th", text: "Current year earnings"
    assert_select "tbody th", text: "Total liabilities and net worth"
    assert_select "tbody td span", text: "5,000.00", minimum: 3
    assert_select "body", text: /Out of balance/, count: 0
  end

  test "balance sheet as of a past date with no comparison" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary,
      amount_kobo: 900_000, effective_date: Date.current.prev_month)

    get balance_sheet_path(as_of: Date.current.prev_month.iso8601, compare: "none")

    assert_response :success
    assert_select "thead th:not(:first-child)", count: 1
    assert_select "tbody td span", text: "9,000.00", minimum: 1
  end

  test "income statement shows the selected period beside the previous one" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary,
      amount_kobo: 300_000, effective_date: Date.current)
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary,
      amount_kobo: 900_000, effective_date: Date.current.prev_month)

    get income_statement_path

    assert_response :success
    assert_select "#statement-heading", "Income and Spending"
    assert_select "thead th", text: Date.current.prev_month.strftime("%b %Y")
    assert_select "tr", text: /Net savings\s+3,000.00\s+9,000.00/

    get income_statement_path(period: "last_month")

    assert_response :success
    assert_select "tr", text: /Net savings\s+9,000.00\s+0.00/
  end

  test "trial balance totals agree and link each account to its ledger" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 500_000)

    get trial_balance_path

    assert_response :success
    assert_select "#statement-heading", "Trial Balance"
    assert_select "#total-debit", "5,000.00"
    assert_select "#total-credit", "5,000.00"
    assert_select "a[href='#{general_ledger_account_path(@cash)}']", "Cash"
  end

  test "general ledger lists accounts and shows an account's lines with a running balance" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 500_000, description: "June salary")

    get general_ledger_path
    assert_response :success
    assert_select "a[href='#{general_ledger_account_path(@cash)}']", text: /Cash/

    get general_ledger_account_path(@cash)
    assert_response :success
    assert_select "tbody th", text: "June salary"
    assert_select "#closing-balance", "5,000.00"
    assert_select "nav[aria-label=Primary] ul[aria-label=Reports] a[aria-current=page]", text: "General ledger"
  end

  test "general ledger only opens accounts in the current workspace" do
    other = provision_business_ledger!(workspaces(:bola_shop)).accounts.first

    get general_ledger_account_path(other)

    assert_response :not_found
  end

  test "reports are listed under Reports in the sidebar" do
    get income_statement_path

    assert_select "nav[aria-label=Primary] details[open] summary", text: "Reports"
    assert_select "nav[aria-label=Primary] ul[aria-label=Reports] a", count: 5
    assert_select "nav[aria-label=Primary] ul[aria-label=Reports] a[aria-current=page]", text: "Income statement"
    assert_select "nav[aria-label=Primary] a", text: "Receivables", count: 0
    assert_select "nav[aria-label=Reports]", count: 0
    assert_select "form[action='#{income_statement_path}']", count: 0
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

  test "cash flow shows operating cash from profit and exports it" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 500_000, description: "Pay")

    get cash_flow_path
    assert_response :success
    assert_select "h1", "Cash flow"
    assert_select "th", text: "Net savings"
    assert_select "a[href=?]", cash_flow_path(format: :csv), text: "Export CSV"

    get cash_flow_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match %r{attachment; filename="cash-flow-#{Date.current.iso8601}\.csv"}, response.headers["Content-Disposition"]
    rows = CSV.parse(response.body)
    assert_equal [ "Code", "Line" ], rows.first.first(2)
    assert_includes rows, [ nil, "Net savings", "5000.00", "0.00" ]
  end

  test "statement and trial balance exports keep the chosen period and figures" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 250_000, effective_date: Date.current.prev_month)

    get income_statement_path(period: "last_month", format: :csv)
    assert_response :success
    assert_includes CSV.parse(response.body).first, Date.current.prev_month.strftime("%b %Y")

    get trial_balance_path(format: :csv)
    rows = CSV.parse(response.body)
    assert_equal [ "Code", "Account", "Debit", "Credit" ], rows.first
    assert_equal [ nil, "Total", "2500.00", "2500.00" ], rows.last
  end

  test "exports guard spreadsheet formulas in names" do
    @cash.update!(name: "=HYPERLINK(\"evil\")")
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 100)

    get trial_balance_path(format: :csv)

    assert_includes CSV.parse(response.body).map(&:second), "'=HYPERLINK(\"evil\")"
  end

  test "an account ledger filters by date and exports the filtered lines" do
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 100_000, effective_date: 10.days.ago.to_date, description: "Older")
    post_journal_entry!(@workspace, debit_account: @cash, credit_account: @salary, amount_kobo: 200_000, description: "Newer")
    from = 2.days.ago.to_date.iso8601

    get general_ledger_account_path(@cash, from: from, to: Date.current.iso8601)
    assert_response :success
    assert_select "tbody th", text: "Newer"
    assert_select "tbody th", text: "Older", count: 0
    assert_select "#closing-balance", "3,000.00"

    get general_ledger_account_path(@cash, from: from, format: :csv)
    rows = CSV.parse(response.body)
    assert_equal [ from, nil, "Opening balance", nil, nil, nil, "1000.00" ], rows.second
    assert_equal [ "Newer" ], rows.map(&:third).grep("Newer")
    assert_equal "3000.00", rows.last.last
  end

  test "report exports return not found without a ledger" do
    user = User.create!(full_name: "No Ledger", email_address: "noledger-csv@example.com", password: "supersecret123")
    workspace = Workspace.create!(name: "No Ledger Co", currency_code: "NGN")
    user.memberships.create!(workspace: workspace, role: :owner)
    sign_in_as(user)

    get cash_flow_path(format: :csv)

    assert_response :not_found
  end

  test "aged receivables only warns when it disagrees with the books" do
    get aged_receivables_path

    assert_response :success
    assert_select "h1", "Owed to you"
    assert_select "#tie-out", count: 0
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

  test "aged receivables explains a gap between invoices and the books" do
    receivable = @ledger.accounts.find_by!(key: "accounts_receivable")
    sales = @ledger.accounts.find_by!(key: "sales")
    entry = @ledger.journal_entries.create!(number: 99, effective_date: Date.current, description: "Posted around the subledger")
    entry.journal_entry_lines.create!(account: receivable, debit: 5_000, credit: 0)
    entry.journal_entry_lines.create!(account: sales, debit: 0, credit: 5_000)

    get aged_receivables_path

    assert_select "#tie-out", text: /Doesn't match your books/
    assert_select "#tie-out li", text: /No customer: books ₦50.00, invoices ₦0.00/
  end

  test "aged payables lists open bills by vendor" do
    rent = @ledger.accounts.find_by!(key: "rent")
    vendor = @workspace.vendors.create!(name: "Lagos Landlords")
    bill = @workspace.bills.create!(user: users(:three), vendor: vendor, bill_date: Date.current,
      bill_lines_attributes: [ { account_id: rent.id, description: "Office rent", amount: "750.00" } ])
    assert bill.issue!

    get aged_payables_path

    assert_response :success
    assert_select "h1", "You owe"
    assert_select "tbody th", text: "Lagos Landlords"
    assert_select "tbody a[href='#{vendor_path(vendor)}']", text: "View"
    assert_select "tbody td", text: "Not due"
    assert_select "#tie-out", count: 0
  end
end
