require "test_helper"

class AccountingEngine::ReverseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(key: "cash")
    @groceries = @ledger.accounts.find_by!(key: "groceries")
    @entry = AccountingEngine.record(
      AccountingEngine::Builders::Entry,
      workspace: @workspace,
      attributes: { effective_date: Date.current, lines: [ { account_id: @groceries.id, debit: 700, credit: 0 }, { account_id: @cash.id, debit: 0, credit: 700 } ] },
      source_id: 1,
      description: "Groceries"
    ).entry
  end

  test "posts the mirror of an entry and links it" do
    receipt = AccountingEngine.reverse(@entry, on: Date.current, source_type: "Entry", source_id: 2, description: "Undo groceries")

    assert receipt.success?
    assert_equal @entry, receipt.entry.reverses_entry
    assert_equal [ [ @cash.id, 700, 0 ], [ @groceries.id, 0, 700 ] ],
      receipt.entry.journal_entry_lines.map { |line| [ line.account_id, line.debit, line.credit ] }.sort
  end

  test "reversing again is a replay, not a second reversal" do
    first = AccountingEngine.reverse(@entry, on: Date.current, source_type: "Entry", source_id: 2)
    again = AccountingEngine.reverse(@entry, on: Date.current, source_type: "Entry", source_id: 2)

    assert again.replayed?
    assert_equal first.entry, again.entry
  end

  test "a different source cannot reverse an entry twice" do
    AccountingEngine.reverse(@entry, on: Date.current, source_type: "Entry", source_id: 2)
    second = AccountingEngine.reverse(@entry, on: Date.current, source_type: "Entry", source_id: 3)

    refute second.success?
    assert_equal :reversal, second.errors.sole.code
  end
end
