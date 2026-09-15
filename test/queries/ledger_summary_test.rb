require "test_helper"

class LedgerSummaryTest < ActiveSupport::TestCase
  test "chart series includes only workspace activity in the selected period and fills empty days" do
    workspace = workspaces(:ada_store)
    cash = Account.for_role!(workspace, :cash)
    income = Account.for_role!(workspace, :uncategorized_income)
    expense = workspace.accounts.create!(name: "Rent", base_type: "expense", account_type: "Personal Outflows", detail_type: "Housing & Utilities")
    post_journal_entry!(workspace, debit_account: cash, credit_account: income, amount_kobo: 500_25)
    post_journal_entry!(workspace, debit_account: expense, credit_account: cash, amount_kobo: 700_50)
    post_journal_entry!(workspace, debit_account: cash, credit_account: income, amount_kobo: 900_00, entry_date: 8.days.ago.to_date)
    other = workspaces(:bola_shop)
    post_journal_entry!(other, debit_account: Account.for_role!(other, :cash), credit_account: Account.for_role!(other, :uncategorized_income), amount_kobo: 999_00)

    summary = LedgerSummary.new(workspace)
    income_series, expense_series = summary.income_expense_series(days: 7)
    assert_equal 7, income_series[:data].size
    assert_equal 500.25, income_series[:data][Date.current]
    assert_equal 700.5, expense_series[:data][Date.current]
    assert_equal 0, income_series[:data][Date.yesterday]
    assert_equal 500.25, income_series[:data].values.sum
    assert_equal(-200.25, summary.performance_series(days: 7).first[:data][Date.current])
  end
end
