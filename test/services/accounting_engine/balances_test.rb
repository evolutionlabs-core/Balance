require "test_helper"

class AccountingEngine::BalancesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @accounts = @ledger.accounts.index_by(&:key)
    @balances = AccountingEngine::Balances.new(@ledger)
  end

  test "sums each account as debit minus credit, in whole kobo" do
    post({ "bank" => 123_456 }, credit: "sales")

    by_account = @balances.by_account

    assert_equal 123_456, by_account.fetch(@accounts["bank"].id)
    assert_equal(-123_456, by_account.fetch(@accounts["sales"].id))
    assert by_account.values.all?(Integer)
  end

  test "limits to entries dated in the range" do
    post({ "bank" => 10_000 }, credit: "sales", on: Date.current.prev_month)
    post({ "bank" => 3_000 }, credit: "sales")

    assert_equal 3_000, @balances.by_account(Date.current.beginning_of_month..Date.current).fetch(@accounts["bank"].id)
    assert_equal 10_000, @balances.by_account(..Date.current.prev_month).fetch(@accounts["bank"].id)
  end

  test "an empty ledger has no balances" do
    assert_empty @balances.by_account
  end

  test "splits a control account by counterparty" do
    acme = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    zenith = @workspace.customers.create!(name: "Zenith", customer_type: "business", email: "zenith@example.com")
    post({ "accounts_receivable" => 5_000 }, credit: "sales", customer: acme)
    post({ "accounts_receivable" => 2_000 }, credit: "sales", customer: zenith)

    assert_equal({ acme.id => 5_000, zenith.id => 2_000 }, @balances.by_counterparty(:customer, subtype: "accounts_receivable"))
  end

  test "lists an account's lines in date order for GL detail" do
    post({ "bank" => 300 }, credit: "sales", on: Date.current)
    post({ "bank" => 100 }, credit: "sales", on: Date.current.prev_day)

    assert_equal [ 100, 300 ], @balances.activity(@accounts["bank"], nil).map(&:debit)
  end

  private
    def post(debits, credit:, on: Date.current, customer: nil)
      lines = debits.map { |key, amount| AccountingEngine::Command::Line.new(account: @accounts.fetch(key), debit: amount, credit: 0, customer: customer) }
      lines << AccountingEngine::Command::Line.new(account: @accounts.fetch(credit), debit: 0, credit: debits.values.sum)
      receipt = AccountingEngine.post(AccountingEngine::Command.new(ledger: @ledger, effective_date: on, lines: lines))
      assert receipt.success?, receipt.errors.join(", ")
    end
end
