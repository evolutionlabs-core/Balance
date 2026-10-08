require "test_helper"

class LedgerCoreTablesTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Core Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit")
    @revenue = LedgerAccount.create!(ledger: @ledger, name: "Revenue", base_type: "revenue", normal_balance: "credit")
  end

  test "creates a balanced entry successfully" do
    entry = @ledger.ledger_entries.build(effective_date: Date.current)
    entry.ledger_lines.build(ledger_account: @cash, debit: 1000, credit: 0)
    entry.ledger_lines.build(ledger_account: @revenue, debit: 0, credit: 1000)

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
end
