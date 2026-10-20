require "test_helper"

class AccountingEngine::TrialBalanceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @accounts = @ledger.accounts.index_by(&:key)
  end

  test "lists accounts with a balance by code, in debit and credit columns that agree" do
    post({ "bank" => 100_000 }, credit: "sales")
    post({ "rent" => 30_000 }, credit: "bank")

    trial_balance = AccountingEngine::TrialBalance.new(@ledger)

    assert_equal %w[1020 4010 5200], trial_balance.rows.map { |row| row.account.code }
    assert_equal [ 70_000, 0 ], trial_balance.rows.first.then { |row| [ row.debit, row.credit ] }
    assert_equal [ 0, 100_000 ], trial_balance.rows.second.then { |row| [ row.debit, row.credit ] }
    assert_equal 100_000, trial_balance.total_debit
    assert trial_balance.balanced?
  end

  test "stops at the as-of date" do
    post({ "bank" => 5_000 }, credit: "sales", on: Date.current.prev_month)
    post({ "bank" => 7_000 }, credit: "sales")

    assert_equal 5_000, AccountingEngine::TrialBalance.new(@ledger, as_of: Date.current.prev_month).total_debit
  end

  private
    def post(debits, credit:, on: Date.current)
      lines = debits.map { |key, amount| AccountingEngine::Command::Line.new(account: @accounts.fetch(key), debit: amount, credit: 0) }
      lines << AccountingEngine::Command::Line.new(account: @accounts.fetch(credit), debit: 0, credit: debits.values.sum)
      assert AccountingEngine.post(AccountingEngine::Command.new(ledger: @ledger, effective_date: on, lines: lines)).success?
    end
end
