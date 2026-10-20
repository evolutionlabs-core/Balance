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

  test "shows every panel with zero figures when there are no journal entries" do
    get overview_path
    assert_response :success
    assert_select "section[aria-labelledby=performance-heading] [role=img]", count: 1
    assert_select "section[aria-labelledby=cash-flow-heading] [role=img]", count: 1
    assert_select "section[aria-labelledby=top-expenses-heading]", text: /No spending in this period./
    assert_select "#position-heading + p", text: /As of/
    assert_select "#recent_feed", count: 0
  end

  test "a personal workspace reads in personal terms" do
    get overview_path

    assert_select "h1 + span", text: "Personal"
    assert_select "[data-kpi] p", text: "Net worth"
    assert_select "[data-kpi] p", text: "Money in"
    assert_select "[data-kpi] p", text: "Money out"
    assert_select "#cash-flow-heading", text: "Cash and bank"
    assert_select "#top-expenses-heading", text: "Where your money went"
    assert_select "#receivables-heading", count: 0
    assert_select "#payables-heading", count: 0
  end

  test "shows overspending as a red amount without a minus sign" do
    ledger = @workspace.provision_ledger!
    groceries = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(@workspace, debit_account: groceries, credit_account: ledger.accounts.find_by!(name: "Cash"), amount_kobo: 34_00)

    get overview_path

    assert_select "[data-kpi=overspent] p", text: "Overspent"
    assert_select "[data-kpi=overspent] p.text-red-700", text: "₦34.00"
    assert_select "[data-kpi=income] p", text: "Nothing in the previous 30 days to compare"
    assert_select "body", text: /-₦34.00/, count: 0
  end

  test "a business workspace reads in business terms and shows what is owed" do
    workspace = workspaces(:chidi_supplies)
    ledger = workspace.provision_ledger!
    sign_in_as(users(:three))
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "rent"), credit_account: ledger.accounts.find_by!(key: "bank"), amount_kobo: 120_00)

    get overview_path

    assert_select "h1 + span", text: "Business"
    assert_select "[data-kpi] p", text: "Revenue"
    assert_select "[data-kpi=net_loss] p", text: "Net loss"
    assert_select "[data-kpi=net_loss] p.text-red-700", text: "₦120.00"
    assert_select "[data-kpi=net_loss] p", text: "Nothing in the previous 30 days to compare"
    assert_select "#receivables-heading", text: "Owed to you"
    assert_select "#payables-heading", text: "You owe"
    assert_select "#accounts-heading", text: "Bank and credit cards"
    assert_select "section[aria-labelledby=accounts-heading] li", text: /Bank/
    assert_select "section[aria-labelledby=accounts-heading] li", text: /Credit Card Payable/, count: 0
    assert_select "section[aria-labelledby=top-expenses-heading] li", text: /Rent/
  end

  test "offers a twelve month period with monthly columns" do
    get overview_path(days: 365)

    assert_select "nav[aria-label='Overview period'] a[aria-current=page][aria-label='12 months']", text: "12M"
    assert_select "section[aria-labelledby=performance-heading] p", text: "Month by month."
  end

  test "the reports section starts closed away from the reports" do
    get overview_path

    assert_select "nav[aria-label=Primary] details:not([open]) summary", text: "Reports"
  end
end
