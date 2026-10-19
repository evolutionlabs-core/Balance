require "test_helper"

class AccountingEngine::RecordTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(key: "cash")
    @groceries = @ledger.accounts.find_by!(key: "groceries")
  end

  test "builds and posts an entry" do
    receipt = record(lines: [ { account_id: @groceries.id, debit: 500, credit: 0 }, { account_id: @cash.id, debit: 0, credit: 500 } ])

    assert receipt.success?
    assert_equal 2, receipt.entry.journal_entry_lines.count
  end

  test "returns a missing account as a receipt error instead of raising" do
    receipt = record(lines: [ { account_id: -1, debit: 500, credit: 0 }, { account_id: @cash.id, debit: 0, credit: 500 } ])

    refute receipt.success?
    assert_equal [ "Account -1 is not in the General ledger." ], receipt.errors
  end

  private
    def record(lines:)
      AccountingEngine.record(
        AccountingEngine::Builders::Entry,
        workspace: @workspace,
        attributes: { effective_date: Date.current, lines: lines },
        source_id: nil,
        description: "Groceries"
      )
    end
end
