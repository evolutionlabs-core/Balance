require "test_helper"

class Engine::PostingOrchestratorTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Engine Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit", code: "4010", subtype: "operating")
  end

  test "posts a balanced command and returns a success receipt" do
    receipt = Engine::PostingOrchestrator.call(command(debit: 1000, credit: 1000))

    assert receipt.success?
    assert_equal :allow, receipt.verdict
    assert_equal @ledger, receipt.entry.ledger

    lines = receipt.entry.ledger_lines.to_a
    assert_equal [ @cash, @income ], lines.map(&:ledger_account)
    assert_equal [ 1000, 0 ], lines.map { |line| line.debit.to_i }
    assert_equal [ 0, 1000 ], lines.map { |line| line.credit.to_i }
    assert_equal 1, @ledger.ledger_entries.count
  end

  test "records the source effect on the entry" do
    receipt = Engine::PostingOrchestrator.call(
      command(debit: 500, credit: 500, source_type: "Invoice", source_id: 7, action: "issue")
    )

    assert receipt.success?
    assert_equal [ "Invoice", 7, "issue" ],
      receipt.entry.values_at(:source_type, :source_id, :action)
  end

  test "rejects an unbalanced command and writes nothing" do
    receipt = Engine::PostingOrchestrator.call(command(debit: 1000, credit: 900))

    refute receipt.success?
    assert_equal :reject, receipt.verdict
    assert_nil receipt.entry
    assert_includes receipt.errors.join, "must equal total credits"
    assert_equal 0, @ledger.ledger_entries.count
    assert_equal 0, LedgerLine.count
  end

  test "rejects a single-line command" do
    command = Engine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [ Engine::Command::Line.new(ledger_account: @cash, debit: 1000, credit: 0) ]
    )

    receipt = Engine::PostingOrchestrator.call(command)

    refute receipt.success?
    assert_includes receipt.errors.join, "at least two lines"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "collects every error instead of stopping at the first" do
    receipt = Engine::PostingOrchestrator.call(command(debit: 1000, credit: 0))

    refute receipt.success?
    assert_operator receipt.errors.size, :>=, 2
  end

  test "rejects an entry on an inactive ledger" do
    @ledger.update!(status: "closed")

    receipt = Engine::PostingOrchestrator.call(command(debit: 1000, credit: 1000))

    refute receipt.success?
    assert_includes receipt.errors.join, "closed"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rejects a line whose account belongs to another ledger" do
    other_workspace = Workspace.create!(name: "Other Workspace", currency_code: "NGN")
    other = Ledger.create!(workspace: other_workspace, name: "General", currency_code: "NGN")
    foreign = LedgerAccount.create!(ledger: other, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")

    command = Engine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        Engine::Command::Line.new(ledger_account: foreign, debit: 1000, credit: 0),
        Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = Engine::PostingOrchestrator.call(command)

    refute receipt.success?
    assert_includes receipt.errors.join, "another ledger"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rejects a command with no ledger" do
    bad = Engine::Command.new(
      ledger: nil,
      effective_date: Date.current,
      lines: [
        Engine::Command::Line.new(ledger_account: @cash, debit: 1000, credit: 0),
        Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = Engine::PostingOrchestrator.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "missing ledger"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rejects a non-numeric amount instead of misparsing it" do
    bad = Engine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        Engine::Command::Line.new(ledger_account: @cash, debit: "lots", credit: 0),
        Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = Engine::PostingOrchestrator.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "must be numbers"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rejects an account that was never persisted" do
    ghost = LedgerAccount.new(ledger: @ledger, name: "Ghost", base_type: "asset", normal_balance: "debit")
    bad = Engine::Command.new(
      ledger: @ledger,
      effective_date: Date.current,
      lines: [
        Engine::Command::Line.new(ledger_account: ghost, debit: 1000, credit: 0),
        Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = Engine::PostingOrchestrator.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "not persisted"
    assert_equal 0, @ledger.ledger_entries.count
  end

  test "rejects a ledger that was never persisted" do
    draft = Ledger.new(workspace: @workspace, name: "Draft", currency_code: "NGN")
    bad = Engine::Command.new(
      ledger: draft,
      effective_date: Date.current,
      lines: [
        Engine::Command::Line.new(ledger_account: @cash, debit: 1000, credit: 0),
        Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
      ]
    )

    receipt = Engine::PostingOrchestrator.call(bad)

    refute receipt.success?
    assert_includes receipt.errors.join, "not persisted"
  end

  private
    def command(debit:, credit:, source_type: nil, source_id: nil, action: nil)
      Engine::Command.new(
        ledger: @ledger,
        effective_date: Date.current,
        source_type: source_type,
        source_id: source_id,
        action: action,
        lines: [
          Engine::Command::Line.new(ledger_account: @cash, debit: debit, credit: 0),
          Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: credit)
        ]
      )
    end
end
