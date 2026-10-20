require "test_helper"

class GetBalanceSummaryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    ledger = @workspace.provision_ledger!
    @cash = ledger.accounts.find_by!(name: "Cash")
    @expense = ledger.accounts.find_by!(name: "Groceries")
    post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000,
      effective_date: Date.current
    )
  end

  test "returns today, this week, this month, and account balances" do
    result = GetBalanceSummary.new(@workspace).execute

    assert_equal [ "Today", "This week", "This month" ], result[:periods].keys
    assert_equal "0.00", result.dig(:periods, "Today", :income_naira)
    assert_equal "2500.00", result.dig(:periods, "Today", :expense_naira)
    assert_equal "-2500.00", result.dig(:periods, "Today", :net_naira)
    assert_includes result[:account_balances].map { |balance| balance[:account] }, "Cash"
  end

  test "ignores entries from other workspaces" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    post_journal_entry!(
      other_workspace,
      debit_account: other_ledger.accounts.find_by!(name: "Rent"),
      credit_account: other_ledger.accounts.find_by!(name: "Cash"),
      amount_kobo: 500_000,
      effective_date: Date.current
    )

    result = GetBalanceSummary.new(@workspace).execute

    assert_equal "2500.00", result.dig(:periods, "Today", :expense_naira)
    refute result[:account_balances].any? { |balance| balance[:balance_naira] == "5000.00" }
  end
end
