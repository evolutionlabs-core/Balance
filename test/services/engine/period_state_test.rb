require "test_helper"

class Engine::PeriodStateTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Period Test", currency_code: "NGN")
    @actor = User.create!(full_name: "Ife Bello", email_address: "close@example.com", password: "supersecret123")
    @workspace.memberships.create!(user: @actor, role: :owner)
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")
    @groceries = LedgerAccount.create!(ledger: @ledger, name: "Groceries", base_type: "expense", normal_balance: "debit", code: "5020", subtype: "groceries")
  end

  test "collects an error when the ledger is closed through the effective date" do
    close_through(Date.current)

    errors = Engine::PeriodState.call(command).errors

    assert errors.one?
    assert_equal :period, errors.first.check
  end

  test "allows a posting dated after the closed-through boundary" do
    close_through(1.month.ago.to_date)

    assert_empty Engine::PeriodState.call(command).errors
  end

  test "treats the boundary date itself as closed" do
    close_through(Date.current)

    assert_not_empty Engine::PeriodState.call(command(effective_date: Date.current)).errors
  end

  test "passes when the ledger was never closed" do
    assert_nil @ledger.closed_through
    assert_empty Engine::PeriodState.call(command).errors
  end

  test "collects an error per line for an inactive account" do
    @cash.update!(active: false, created_by: "admin")

    errors = Engine::PeriodState.call(command).errors

    assert_equal 1, errors.size
    assert_equal :account, errors.first.check
    assert_match /Line 2: account Cash is inactive/, errors.first.to_s
  end

  test "collects ledger, account, and period errors together" do
    @cash.update!(active: false, created_by: "admin")
    @ledger.update!(status: "closed")
    close_through(Date.current)

    errors = Engine::PeriodState.call(command).errors

    assert_equal [ :ledger, :account, :period ], errors.map(&:check)
  end

  private
    def close_through(date)
      close = Ledgers::Close.call(ledger: @ledger, through: date, actor: @actor)
      raise close.error unless close.ok?
    end

    def command(effective_date: Date.current)
      Engine::Command.new(
        ledger: @ledger,
        effective_date: effective_date,
        action: "create",
        lines: [
          Engine::Command::Line.new(ledger_account: @groceries, debit: 100_00, credit: 0),
          Engine::Command::Line.new(ledger_account: @cash, debit: 0, credit: 100_00)
        ]
      )
    end
end
