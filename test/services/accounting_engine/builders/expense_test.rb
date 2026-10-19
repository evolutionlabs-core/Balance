require "test_helper"

class AccountingEngine::Builders::ExpenseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @bank = account("Checking Account")
    @groceries = account("Groceries")
    @housing = account("Housing")
  end

  test "builds a debit line per category and one credit line for the payment account" do
    command = AccountingEngine::Builders::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    assert_instance_of AccountingEngine::Command, command
    assert_equal @workspace.ledgers.first, command.ledger
    assert_equal Date.current, command.effective_date
    assert_equal "Expense", command.source_type
    assert_equal 7, command.source_id
    assert_equal "create", command.action

    lines = command.lines
    assert_equal 3, lines.length

    groceries = account("Groceries")
    housing = account("Housing")
    bank = account("Checking Account")

    assert_equal [ [ groceries, 4_000_000, 0 ], [ housing, 2_000_000, 0 ], [ bank, 0, 6_000_000 ] ],
      lines.map { |line| [ line.account, line.debit, line.credit ] }
  end

  test "passes kobo through as whole minor units" do
    command = AccountingEngine::Builders::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    assert_equal 6_000_000, command.lines.sum(&:debit)
    assert_equal 6_000_000, command.lines.sum(&:credit)
  end

  test "composes only the lines the model submits" do
    command = AccountingEngine::Builders::Expense.call(
      workspace: @workspace,
      attributes: attributes(expense_lines: [ { account_id: @housing.id, amount_kobo: 2_000_000 } ]),
      source_id: 7
    )

    lines = command.lines
    assert_equal 2, lines.length
    assert_equal [ account("Housing"), account("Checking Account") ],
      lines.map(&:account)
    assert_equal 2_000_000, lines.sum(&:debit)
    assert_equal 2_000_000, lines.sum(&:credit)
  end

  test "resolves the account directly from the selected account" do
    command = AccountingEngine::Builders::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    groceries_line = command.lines.find { |line| line.account.name == "Groceries" }

    assert_equal "5020", groceries_line.account.code
    assert_equal "expense", groceries_line.account.base_type
  end

  test "resolves a ledger from the workspace when one exists" do
    ledger = @workspace.ledgers.first

    command = AccountingEngine::Builders::Expense.call(workspace: @workspace, attributes: attributes, source_id: 7)

    assert_equal ledger, command.ledger
    assert_equal 1, @workspace.ledgers.count
  end

  test "requires the workspace ledger to be provisioned already" do
    workspace = Workspace.create!(name: "Fresh Workspace", currency_code: "NGN")

    adapter = AccountingEngine::Builders::Expense.new(workspace: workspace, attributes: {}, source_id: nil)

    assert_raises(ActiveRecord::RecordNotFound) { adapter.send(:ledger) }
    assert_not workspace.ledgers.exists?
  end

  private
    def attributes(payment_account_id: @bank.id, expense_lines: [
      { account_id: @groceries.id, amount_kobo: 4_000_000 },
      { account_id: @housing.id, amount_kobo: 2_000_000 }
    ])
      {
        payment_date: Date.current,
        payment_account_id: payment_account_id,
        expense_lines: expense_lines
      }
    end

    def account(name)
      @ledger.accounts.find_by!(name: name)
    end
end
