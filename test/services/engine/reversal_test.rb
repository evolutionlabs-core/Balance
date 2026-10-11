require "test_helper"

class Engine::ReversalTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Reversal Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit")
  end

  test "posts an exact mirror linked to the original" do
    original = post_entry
    receipt = Engine::Reversal.call(original)

    assert receipt.success?
    assert_equal :allow, receipt.verdict

    reversal = receipt.entry
    assert_equal @ledger, reversal.ledger
    assert_equal original, reversal.reverses_ledger_entry

    mirrored = reversal.ledger_lines.to_h do |line|
      [ line.ledger_account.name, [ line.debit.to_i, line.credit.to_i ] ]
    end
    assert_equal [ 0, 1000 ], mirrored["Cash"]
    assert_equal [ 1000, 0 ], mirrored["Income"]
  end

  test "refuses to reverse a reversal" do
    original = post_entry
    reversal = Engine::Reversal.call(original).entry

    receipt = Engine::Reversal.call(reversal)

    refute receipt.success?
    assert_equal :reject, receipt.verdict
    assert_nil receipt.entry
    assert_includes receipt.errors.join, "itself a reversal"
    assert_equal 2, @ledger.ledger_entries.count
  end

  test "refuses a second reversal of the same entry" do
    original = post_entry
    Engine::Reversal.call(original)

    receipt = Engine::Reversal.call(original)

    refute receipt.success?
    assert_equal :reject, receipt.verdict
    assert_includes receipt.errors.join, "already been reversed"
    assert_equal 2, @ledger.ledger_entries.count
  end

  private
    def post_entry
      receipt = Engine::PostingOrchestrator.call(
        Engine::Command.new(
          ledger: @ledger,
          effective_date: Date.current,
          lines: [
            Engine::Command::Line.new(ledger_account: @cash, debit: 1000, credit: 0),
            Engine::Command::Line.new(ledger_account: @income, debit: 0, credit: 1000)
          ]
        )
      )

      assert receipt.success?, receipt.errors.join(", ")
      receipt.entry
    end
end
