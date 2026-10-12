require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = Ledgers::Provisioner.call(workspace: @workspace, template: "personal_finance")
    @bank = ledger_account("Checking Account")
    @fuel = ledger_account("Groceries")
  end

  test "stores the computed total" do
    expense = build_expense

    expense.save!

    assert_equal 4_000_000, expense.total_kobo
  end

  test "supports split category lines" do
    uniforms = ledger_account("Housing")
    expense = build_expense
    expense.expense_lines.build(account: uniforms, description: "Uniform", amount_kobo: 1_000_000, position: 1)

    assert_equal 5_000_000, expense.total_kobo
    assert_equal "Fuel and Uniform", expense.description
    assert_equal "Groceries and Housing", expense.category_label
  end

  test "rejects an ineligible payment account" do
    loan = ledger_account("Auto Loan")
    expense = build_expense(payment_account: loan)

    assert_not expense.valid?
    assert_includes expense.errors[:payment_account], "must be a cash or credit-card account"
  end

  test "accepts a credit-card payment account" do
    credit_card = ledger_account("Credit Card")

    assert build_expense(payment_account: credit_card).valid?
  end

  test "rejects payment dates too far in the past" do
    expense = build_expense
    expense.payment_date = 10.years.ago.to_date - 1.day

    assert_not expense.valid?
    assert_includes expense.errors[:payment_date], "is too far in the past"
  end

  test "rejects an ineligible category account" do
    income = ledger_account("Salary")
    expense = build_expense(category: income)

    assert_not expense.valid?
    assert_includes expense.expense_lines.first.errors[:account], "is not an eligible expense category"
  end

  test "rejects non-finite and sub-kobo amount input" do
    expense = build_expense
    line = expense.expense_lines.first

    line.amount = "NaN"
    assert_not expense.valid?
    assert_includes line.errors[:amount], "must be a valid number"

    line.amount = "1.999"
    assert_not expense.valid?
    assert_includes line.errors[:amount], "must be a valid number"
  end

  test "posted expense lines are immutable" do
    expense = build_expense
    expense.save!
    expense.mark_posted!
    line = expense.expense_lines.first

    assert_not line.update(description: "Changed")
    assert_equal "Fuel", line.reload.description
  end

  private
    def ledger_account(name)
      @ledger.ledger_accounts.find_by!(name: name)
    end

    def build_expense(payment_account: @bank, category: @fuel, memo: nil, payment_date: Date.current)
      @workspace.expenses.build(
        payment_date: payment_date,
        payment_account: payment_account,
        memo: memo,
        expense_lines_attributes: [
          { account: category, description: "Fuel", amount_kobo: 4_000_000, position: 0 }
        ]
      )
    end
end
