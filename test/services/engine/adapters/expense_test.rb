require "test_helper"

class Engine::Adapters::ExpenseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @bank = ledger_account("Checking Account")
    @groceries = ledger_account("Groceries")
    @housing = ledger_account("Housing")
  end

  test "builds a debit line per category and one credit line for the payment account" do
    command = Engine::Adapters::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    assert_instance_of Engine::Command, command
    assert_equal @workspace.ledgers.first, command.ledger
    assert_equal Date.current, command.effective_date
    assert_equal "Expense", command.source_type
    assert_equal 7, command.source_id
    assert_equal "create", command.action

    lines = command.lines
    assert_equal 3, lines.length

    groceries = ledger_account("Groceries")
    housing = ledger_account("Housing")
    bank = ledger_account("Checking Account")

    assert_equal [ [ groceries, 4_000_000, 0 ], [ housing, 2_000_000, 0 ], [ bank, 0, 6_000_000 ] ],
      lines.map { |line| [ line.ledger_account, line.debit, line.credit ] }
  end

  test "passes kobo through as whole minor units" do
    command = Engine::Adapters::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    assert_equal 6_000_000, command.lines.sum(&:debit)
    assert_equal 6_000_000, command.lines.sum(&:credit)
  end

  test "composes only the lines the model submits" do
    command = Engine::Adapters::Expense.call(
      workspace: @workspace,
      attributes: attributes(expense_lines: [ { account_id: @housing.id, amount_kobo: 2_000_000 } ]),
      source_id: 7
    )

    lines = command.lines
    assert_equal 2, lines.length
    assert_equal [ ledger_account("Housing"), ledger_account("Checking Account") ],
      lines.map(&:ledger_account)
    assert_equal 2_000_000, lines.sum(&:debit)
    assert_equal 2_000_000, lines.sum(&:credit)
  end

  test "resolves the ledger account directly from the selected account" do
    command = Engine::Adapters::Expense.call(
      workspace: @workspace,
      attributes: attributes,
      source_id: 7
    )

    groceries_line = command.lines.find { |line| line.ledger_account.name == "Groceries" }

    assert_equal "5020", groceries_line.ledger_account.code
    assert_equal "expense", groceries_line.ledger_account.base_type
  end

  test "resolves a ledger from the workspace when one exists" do
    ledger = @workspace.ledgers.first

    command = Engine::Adapters::Expense.call(workspace: @workspace, attributes: attributes, source_id: 7)

    assert_equal ledger, command.ledger
    assert_equal 1, @workspace.ledgers.count
  end

  test "provisions the workspace ledger on demand" do
    workspace = Workspace.create!(name: "Fresh Workspace", currency_code: "NGN")

    adapter = Engine::Adapters::Expense.new(workspace: workspace, attributes: {}, source_id: nil)

    assert_equal "General", adapter.send(:ledger).name
    assert_includes workspace.ledgers.first.ledger_accounts.map(&:name), "Housing"
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

    def ledger_account(name)
      @ledger.ledger_accounts.find_by!(name: name)
    end
end
