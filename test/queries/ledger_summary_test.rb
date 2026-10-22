require "test_helper"

class LedgerSummaryTest < ActiveSupport::TestCase
  test "chart series includes only workspace activity in the selected period and fills empty days" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    cash = ledger.accounts.find_by!(name: "Cash")
    income = ledger.accounts.find_by!(name: "Salary")
    expense = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(workspace, debit_account: cash, credit_account: income, amount_kobo: 500_25)
    post_journal_entry!(workspace, debit_account: expense, credit_account: cash, amount_kobo: 700_50)
    post_journal_entry!(workspace, debit_account: cash, credit_account: income, amount_kobo: 900_00, effective_date: 8.days.ago.to_date)
    other = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other)
    post_journal_entry!(
      other,
      debit_account: other_ledger.accounts.find_by!(name: "Cash"),
      credit_account: other_ledger.accounts.find_by!(name: "Sales"),
      amount_kobo: 999_00
    )

    summary = LedgerSummary.new(workspace)
    income_series, expense_series = summary.income_expense_series(days: 7)
    assert_equal 7, income_series[:data].size
    assert_equal 500.25, income_series[:data][Date.current]
    assert_equal 700.5, expense_series[:data][Date.current]
    assert_equal 0, income_series[:data][Date.yesterday]
    assert_equal 500.25, income_series[:data].values.sum
    assert_equal(-200.25, summary.performance_series(days: 7).first[:data][Date.current])
    assert_equal 0, summary.performance_series(days: 7).first[:data][Date.yesterday]

    weekly_income, = summary.income_expense_series(days: 90)
    assert_equal 900 + 500.25, weekly_income[:data].values.sum
    assert weekly_income[:data].keys.all? { |date| date == date.beginning_of_week }
  end

  test "summarizes balances from journal entry lines across all posted entries" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    cash = ledger.accounts.find_by!(name: "Cash")
    income = ledger.accounts.find_by!(name: "Salary")
    expense = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(workspace, debit_account: cash, credit_account: income, amount_kobo: 500_00)
    post_journal_entry!(workspace, debit_account: expense, credit_account: cash, amount_kobo: 200_00)

    summary = LedgerSummary.new(workspace)

    assert_equal 300_00, summary.liquid_balance_kobo
    assert_equal 500_00, summary.today.income_kobo
    assert_equal 200_00, summary.today.expense_kobo
    assert_equal 300_00, summary.today.profit_kobo
  end

  test "cash flow starts from the balance before the period and ends at today's cash" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    cash = ledger.accounts.find_by!(name: "Cash")
    savings = ledger.accounts.find_by!(name: "Savings Account")
    salary = ledger.accounts.find_by!(name: "Salary")
    groceries = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(workspace, debit_account: cash, credit_account: salary, amount_kobo: 1_000_00, effective_date: 40.days.ago.to_date)
    post_journal_entry!(workspace, debit_account: cash, credit_account: salary, amount_kobo: 400_00, effective_date: 3.days.ago.to_date)
    post_journal_entry!(workspace, debit_account: savings, credit_account: cash, amount_kobo: 250_00, effective_date: 2.days.ago.to_date)
    post_journal_entry!(workspace, debit_account: groceries, credit_account: cash, amount_kobo: 150_00)

    flow = LedgerSummary.new(workspace).cash_flow(days: 30)

    assert_equal 1_000_00, flow.opening_kobo
    assert_equal 400_00, flow.incoming_kobo, "a transfer to savings is not money in"
    assert_equal 150_00, flow.outgoing_kobo, "a transfer to savings is not money out"
    assert_equal 1_250_00, flow.closing_kobo
    assert_equal LedgerSummary.new(workspace).liquid_balance_kobo, flow.closing_kobo
    assert_equal 30, flow.series.size
    assert_equal 1_000.0, flow.series[29.days.ago.to_date]
    assert_equal 1_250.0, flow.series[Date.current]
  end

  test "groups a twelve month period by month" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(name: "Cash"), credit_account: ledger.accounts.find_by!(name: "Salary"), amount_kobo: 700_00, effective_date: 200.days.ago.to_date)

    income, = LedgerSummary.new(workspace).income_expense_series(days: 365)

    assert income[:data].keys.all? { |date| date == date.beginning_of_month }
    assert_equal 700.0, income[:data].values.sum
  end

  test "expense breakdown comes from the ledger and adds up to the period's expenses" do
    workspace = workspaces(:chidi_supplies)
    ledger = workspace.provision_ledger!
    bank = ledger.accounts.find_by!(key: "bank")
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "rent"), credit_account: bank, amount_kobo: 900_00)
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "marketing"), credit_account: bank, amount_kobo: 300_00)
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "rent"), credit_account: bank, amount_kobo: 50_00, effective_date: 45.days.ago.to_date)

    summary = LedgerSummary.new(workspace)
    breakdown = summary.expense_breakdown(days: 30)

    assert_equal [ [ "Rent", 900_00 ], [ "Marketing", 300_00 ] ], breakdown.map { |row| [ row.account.name, row.amount_kobo ] }
    assert_equal summary.period(days: 30).expense_kobo, breakdown.sum(&:amount_kobo)
  end

  test "account balances show liabilities as amounts owed" do
    workspace = workspaces(:chidi_supplies)
    ledger = workspace.provision_ledger!
    card = ledger.accounts.find_by!(key: "credit_card")
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "utilities"), credit_account: card, amount_kobo: 80_00)
    post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: "bank"), credit_account: ledger.accounts.find_by!(key: "sales"), amount_kobo: 500_00)

    balances = LedgerSummary.new(workspace).account_balances(subtypes: %w[cash credit_card]).to_h { |row| [ row.account.name, row.amount_kobo ] }

    assert_equal({ "Cash" => 0, "Bank" => 500_00, "Credit Card Payable" => 80_00 }, balances)
  end
end
