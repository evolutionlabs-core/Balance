require "test_helper"

class LedgerSummaryTest < ActiveSupport::TestCase
  test "chart series includes only workspace activity in the selected period and fills empty days" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!(template: "personal_finance")
    cash = ledger.ledger_accounts.find_by!(name: "Cash")
    income = ledger.ledger_accounts.find_by!(name: "Salary")
    expense = ledger.ledger_accounts.find_by!(name: "Groceries")
    post_ledger_entry!(workspace, debit_ledger_account: cash, credit_ledger_account: income, amount_kobo: 500_25)
    post_ledger_entry!(workspace, debit_ledger_account: expense, credit_ledger_account: cash, amount_kobo: 700_50)
    post_ledger_entry!(workspace, debit_ledger_account: cash, credit_ledger_account: income, amount_kobo: 900_00, effective_date: 8.days.ago.to_date)
    other = workspaces(:bola_shop)
    other_ledger = other.provision_ledger!(template: "standard_sme")
    post_ledger_entry!(
      other,
      debit_ledger_account: other_ledger.ledger_accounts.find_by!(name: "Cash"),
      credit_ledger_account: other_ledger.ledger_accounts.find_by!(name: "Sales"),
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
  end

  test "summarizes balances from ledger lines across all posted entries" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!(template: "personal_finance")
    cash = ledger.ledger_accounts.find_by!(name: "Cash")
    income = ledger.ledger_accounts.find_by!(name: "Salary")
    expense = ledger.ledger_accounts.find_by!(name: "Groceries")
    post_ledger_entry!(workspace, debit_ledger_account: cash, credit_ledger_account: income, amount_kobo: 500_00)
    post_ledger_entry!(workspace, debit_ledger_account: expense, credit_ledger_account: cash, amount_kobo: 200_00)

    summary = LedgerSummary.new(workspace)

    assert_equal 300_00, summary.liquid_balance_kobo
    assert_equal 500_00, summary.today.income_kobo
    assert_equal 200_00, summary.today.expense_kobo
    assert_equal 300_00, summary.today.profit_kobo
    assert_equal 300_00, summary.trial_balance.find { |line| line.account.name == "Cash" }.debit_kobo
  end
end
