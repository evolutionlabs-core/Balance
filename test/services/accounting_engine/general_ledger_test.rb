require "test_helper"

class AccountingEngine::GeneralLedgerTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @accounts = @ledger.accounts.index_by(&:key)
  end

  test "carries an opening balance and a running balance in the account's normal sign" do
    post({ "bank" => 50_000 }, credit: "sales", on: Date.current.prev_year)
    post({ "bank" => 20_000 }, credit: "sales", on: Date.current.beginning_of_year)
    post({ "rent" => 5_000 }, credit: "bank", on: Date.current)

    ledger = AccountingEngine::GeneralLedger.new(@accounts["bank"], from: Date.current.beginning_of_year)

    assert_equal 50_000, ledger.opening_balance
    assert_equal [ 70_000, 65_000 ], ledger.lines.map(&:balance)
    assert_equal 65_000, ledger.closing_balance
  end

  test "credit-normal accounts grow with credits" do
    post({ "bank" => 20_000 }, credit: "sales")

    assert_equal 20_000, AccountingEngine::GeneralLedger.new(@accounts["sales"], from: Date.current.beginning_of_year).closing_balance
  end

  private
    def post(debits, credit:, on: Date.current)
      lines = debits.map { |key, amount| AccountingEngine::Command::Line.new(account: @accounts.fetch(key), debit: amount, credit: 0) }
      lines << AccountingEngine::Command::Line.new(account: @accounts.fetch(credit), debit: 0, credit: debits.values.sum)
      assert AccountingEngine.post(AccountingEngine::Command.new(ledger: @ledger, effective_date: on, lines: lines)).success?
    end
end
