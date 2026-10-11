require "test_helper"

class LedgerCoreTablesTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Core Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit", code: "4010", subtype: "operating")
  end

  test "creates a balanced entry successfully" do
    entry = @ledger.ledger_entries.build(effective_date: Date.current)
    entry.ledger_lines.build(ledger_account: @cash, debit: 1000, credit: 0)
    entry.ledger_lines.build(ledger_account: @income, debit: 0, credit: 1000)

    assert entry.save
    assert_equal 2, entry.ledger_lines.count
  end

  test "rejects a line with both debit and credit" do
    entry = @ledger.ledger_entries.build(effective_date: Date.current)
    entry.ledger_lines.build(ledger_account: @cash, debit: 100, credit: 100)

    assert_raises(ActiveRecord::CheckViolation) do
      entry.save!
    end
  end

  test "rejects duplicate source effects" do
    @ledger.ledger_entries.create!(
      effective_date: Date.current,
      source_type: "Invoice",
      source_id: 1,
      action: "issue"
    )

    duplicate = @ledger.ledger_entries.build(
      effective_date: Date.current,
      source_type: "Invoice",
      source_id: 1,
      action: "issue"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!
    end
  end

  test "a posted entry cannot be updated or destroyed" do
    entry = @ledger.ledger_entries.create!(effective_date: Date.current)

    assert_not entry.update(effective_date: Date.current + 1)
    assert_equal Date.current, entry.reload.effective_date
    assert_not entry.destroy
    assert_equal 1, @ledger.ledger_entries.count
  end

  test "a posted line cannot be updated or destroyed" do
    entry = @ledger.ledger_entries.create!(effective_date: Date.current)
    line = entry.ledger_lines.create!(ledger_account: @cash, debit: 1000, credit: 0)

    assert_not line.update(debit: 5000)
    assert_equal 1000, line.reload.debit.to_i
    assert_not line.destroy
    assert_equal 1, entry.ledger_lines.count
  end
end
