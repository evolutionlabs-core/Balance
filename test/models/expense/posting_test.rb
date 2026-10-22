require "test_helper"

class Expense::PostingTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @bank = @ledger.accounts.find_by!(name: "Checking Account")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
  end

  test "records the expense through the engine and marks it posted" do
    expense = build_expense

    assert expense.record_entry!
    assert expense.reload.posted?
    assert_not_nil expense.journal_entry
  end

  test "posts nothing and stays a draft when the engine rejects" do
    @workspace.ledger.update!(status: "archived")
    expense = build_expense

    assert_equal false, expense.record_entry!

    refute expense.reload.posted?
    assert_empty JournalEntry.where(source_type: "Expense")
    assert_includes expense.errors.full_messages, "Ledger General is archived"
  end

  test "an invalid expense records nothing and carries the model errors" do
    expense = @workspace.expenses.build(payment_date: Date.current, payment_account: @bank)
    expense.expense_lines.build(account: @groceries, description: "Fuel", amount_kobo: -1, position: 0)

    assert_equal false, expense.record_entry!
    assert expense.errors.any?
    assert_empty JournalEntry.where(source_type: "Expense")
  end

  private
    def build_expense
      expense = @workspace.expenses.build(payment_date: Date.current, payment_account: @bank, memo: "Team lunch")
      expense.expense_lines.build(account: @groceries, description: "Fuel", amount_kobo: 40_000_00, position: 0)
      expense.save!
      expense
    end
end
