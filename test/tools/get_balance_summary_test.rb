require "test_helper"

class GetBalanceSummaryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = ledger.ledger_accounts.find_by!(name: "Cash")
    @expense = ledger.ledger_accounts.find_by!(name: "Groceries")
    post_ledger_entry!(
      @workspace,
      debit_ledger_account: @expense,
      credit_ledger_account: @cash,
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
    other_ledger = other_workspace.provision_ledger!(template: "standard_sme")
    post_ledger_entry!(
      other_workspace,
      debit_ledger_account: other_ledger.ledger_accounts.find_by!(name: "Rent"),
      credit_ledger_account: other_ledger.ledger_accounts.find_by!(name: "Cash"),
      amount_kobo: 500_000,
      effective_date: Date.current
    )

    result = GetBalanceSummary.new(@workspace).execute

    assert_equal "2500.00", result.dig(:periods, "Today", :expense_naira)
    refute result[:account_balances].any? { |balance| balance[:balance_naira] == "5000.00" }
  end
end
