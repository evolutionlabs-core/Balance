require "test_helper"

class LedgerCoreTablesTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Core Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = Account.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit", code: "1010", subtype: "cash")
    @income = Account.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit", code: "4010", subtype: "operating")
  end

  test "creates a balanced entry successfully" do
    entry = @ledger.journal_entries.build(number: 1, effective_date: Date.current)
    entry.journal_entry_lines.build(account: @cash, debit: 1000, credit: 0)
    entry.journal_entry_lines.build(account: @income, debit: 0, credit: 1000)

    assert entry.save
    assert_equal 2, entry.journal_entry_lines.count
  end

  test "rejects a line with both debit and credit" do
    entry = @ledger.journal_entries.build(number: 1, effective_date: Date.current)
    entry.journal_entry_lines.build(account: @cash, debit: 100, credit: 100)

    assert_raises(ActiveRecord::CheckViolation) do
      entry.save!
    end
  end

  test "rejects duplicate source effects" do
    @ledger.journal_entries.create!(
      number: 1,
      effective_date: Date.current,
      source_type: "Invoice",
      source_id: 1,
      action: "issue"
    )

    duplicate = @ledger.journal_entries.build(
      number: 2,
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
    entry = @ledger.journal_entries.create!(number: 1, effective_date: Date.current)

    assert_not entry.update(effective_date: Date.current + 1)
    assert_equal Date.current, entry.reload.effective_date
    assert_not entry.destroy
    assert_equal 1, @ledger.journal_entries.count
  end

  test "a posted line cannot be updated or destroyed" do
    entry = @ledger.journal_entries.create!(number: 1, effective_date: Date.current)
    line = entry.journal_entry_lines.create!(account: @cash, debit: 1000, credit: 0)

    assert_not line.update(debit: 5000)
    assert_equal 1000, line.reload.debit.to_i
    assert_not line.destroy
    assert_equal 1, entry.journal_entry_lines.count
  end

  test "rejects a reused entry number within a ledger" do
    @ledger.journal_entries.create!(number: 1, effective_date: Date.current)

    assert_raises(ActiveRecord::RecordNotUnique) do
      @ledger.journal_entries.create!(number: 1, effective_date: Date.current)
    end
  end

  test "an entry can be reversed only once" do
    original = @ledger.journal_entries.create!(number: 1, effective_date: Date.current)
    @ledger.journal_entries.create!(number: 2, effective_date: Date.current, reverses_entry: original)

    assert original.reload.reversed?
    assert_raises(ActiveRecord::RecordNotUnique) do
      @ledger.journal_entries.create!(number: 3, effective_date: Date.current, reverses_entry: original)
    end
  end

  test "line amounts are whole kobo" do
    assert_equal :integer, JournalEntryLine.type_for_attribute(:debit).type
    assert_equal :integer, JournalEntryLine.type_for_attribute(:credit).type
  end
end
