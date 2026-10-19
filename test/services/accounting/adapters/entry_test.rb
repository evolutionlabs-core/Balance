require "test_helper"

class Accounting::Adapters::EntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @expense = @ledger.accounts.find_by!(name: "Groceries")
    @cash = @ledger.accounts.find_by!(name: "Cash")
  end

  test "builds a create command from account lines" do
    command = Accounting::Adapters::Entry.call(
      workspace: @workspace,
      attributes: {
        action: "create",
        effective_date: "2026-10-13",
        lines: [
          { account_id: @expense.id, debit: 250_000, credit: 0 },
          { account_id: @cash.id, debit: 0, credit: 250_000 }
        ]
      },
      source_id: 11,
      description: "Weekly shop"
    )

    assert_instance_of Accounting::Command, command
    assert_equal @ledger, command.ledger
    assert_equal "Entry", command.source_type
    assert_equal 11, command.source_id
    assert_equal "create", command.action
    assert_equal Date.new(2026, 10, 13), command.effective_date
    assert_equal "Weekly shop", command.description

    lines = command.lines
    assert_equal [ @expense, @cash ], lines.map(&:account)
    assert_equal [ 250_000, 0 ], lines.map(&:debit)
    assert_equal [ 0, 250_000 ], lines.map(&:credit)
  end

  test "passes pre-computed mirror lines through with the reverse action" do
    command = Accounting::Adapters::Entry.call(
      workspace: @workspace,
      attributes: {
        action: "reverse",
        effective_date: Date.current,
        lines: [
          { account_id: @cash.id, debit: 250_000, credit: 0 },
          { account_id: @expense.id, debit: 0, credit: 250_000 }
        ]
      },
      source_id: 12
    )

    assert_equal "reverse", command.action
    assert_equal "Entry", command.source_type
    lines = command.lines
    assert_equal [ @cash, @expense ], lines.map(&:account)
    assert_equal [ 250_000, 0 ], lines.map(&:debit)
    assert_equal [ 0, 250_000 ], lines.map(&:credit)
  end

  test "defaults the action to create" do
    command = Accounting::Adapters::Entry.call(
      workspace: @workspace,
      attributes: {
        effective_date: Date.current,
        lines: [
          { account_id: @expense.id, debit: 100, credit: 0 },
          { account_id: @cash.id, debit: 0, credit: 100 }
        ]
      },
      source_id: 13
    )

    assert_equal "create", command.action
  end

  test "raises when a line references a missing account" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      Accounting::Adapters::Entry.call(
        workspace: @workspace,
        attributes: {
          effective_date: Date.current,
          lines: [
            { account_id: -1, debit: 100, credit: 0 },
            { account_id: @cash.id, debit: 0, credit: 100 }
          ]
        },
        source_id: 14
      )
    end

    assert_instance_of ActiveRecord::RecordNotFound, error
  end
end
