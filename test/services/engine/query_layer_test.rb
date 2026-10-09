require "test_helper"

class Engine::QueryLayerTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Query Test", currency_code: "NGN")
    @ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: "NGN")
    @cash = LedgerAccount.create!(ledger: @ledger, name: "Cash", base_type: "asset", normal_balance: "debit")
    @income = LedgerAccount.create!(ledger: @ledger, name: "Income", base_type: "income", normal_balance: "credit")
    @rent = LedgerAccount.create!(ledger: @ledger, name: "Rent", base_type: "expense", normal_balance: "debit")
  end

  test "aggregates net balances per account" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))
    post_entry(debit: @rent, credit: @cash, amount: 250, on: Date.new(2026, 1, 2))

    result = query(as_of: Date.new(2026, 1, 31))
    nets = result.balances.to_h { |balance| [ balance.ledger_account.name, balance.net ] }

    assert_equal 750, nets["Cash"]
    assert_equal(-1000, nets["Income"])
    assert_equal 250, nets["Rent"]
  end

  test "keeps amounts decimal rather than floating point" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))

    result = query(as_of: Date.new(2026, 1, 31))

    assert(result.balances.all? { |balance| balance.net.is_a?(BigDecimal) })
    assert(result.trial_balance.all? { |line| line.debit.is_a?(BigDecimal) && line.credit.is_a?(BigDecimal) })
  end

  test "excludes entries after the as_of date" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))
    post_entry(debit: @cash, credit: @income, amount: 500, on: Date.new(2026, 3, 1))

    result = query(as_of: Date.new(2026, 1, 31))

    assert_equal 1000, cash_net(result)
    assert_equal 1, result.entries.size
    assert_equal Date.new(2026, 1, 31), result.as_of
  end

  test "defaults the snapshot to today" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.current)
    post_entry(debit: @cash, credit: @income, amount: 500, on: 1.year.from_now.to_date)

    result = query

    assert_equal Date.current, result.as_of
    assert_equal 1000, cash_net(result)
  end

  test "scopes balances and history to the requested accounts" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))
    post_entry(debit: @rent, credit: @cash, amount: 250, on: Date.new(2026, 1, 2))

    result = query(as_of: Date.new(2026, 1, 31), account_ids: [ @cash.id ])

    assert_equal [ "Cash" ], result.balances.map { |balance| balance.ledger_account.name }
    assert_equal 750, cash_net(result)
    assert_equal 2, result.entries.size
  end

  test "composes a balanced trial balance" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))

    result = query(as_of: Date.new(2026, 1, 31))
    columns = result.trial_balance.to_h { |line| [ line.ledger_account.name, [ line.debit, line.credit ] ] }

    assert_equal [ 1000, 0 ], columns["Cash"]
    assert_equal [ 0, 1000 ], columns["Income"]
    refute_includes columns.keys, "Rent"
    assert_equal columns.values.sum(&:first), columns.values.sum(&:last)
  end

  test "orders history by effective date" do
    post_entry(debit: @cash, credit: @income, amount: 300, on: Date.new(2026, 1, 3))
    post_entry(debit: @cash, credit: @income, amount: 200, on: Date.new(2026, 1, 1))

    result = query(as_of: Date.new(2026, 1, 31))

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 3) ], result.entries.map(&:effective_date)
  end

  test "ignores entries belonging to another ledger" do
    other = Ledger.create!(workspace: @workspace, name: "Other", currency_code: "NGN")
    other_cash = LedgerAccount.create!(ledger: other, name: "Cash", base_type: "asset", normal_balance: "debit")
    other_income = LedgerAccount.create!(ledger: other, name: "Income", base_type: "income", normal_balance: "credit")

    post_entry(ledger: other, debit: other_cash, credit: other_income, amount: 9999, on: Date.new(2026, 1, 1))

    result = query(as_of: Date.new(2026, 1, 31))

    assert_empty result.entries
    assert_equal 0, cash_net(result)
  end

  test "still reports on a closed ledger" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))
    @ledger.update!(status: "closed")

    result = query(as_of: Date.new(2026, 1, 31))

    assert_equal 1000, cash_net(result)
    assert_equal 1, result.entries.size
  end

  test "returns an empty result for an unused ledger" do
    result = query(as_of: Date.new(2026, 1, 31))

    assert_empty result.entries
    assert_empty result.trial_balance
    assert_equal @ledger, result.ledger
    assert(result.balances.all? { |balance| balance.net.zero? })
  end

  test "reads inside an open transaction" do
    post_entry(debit: @cash, credit: @income, amount: 1000, on: Date.new(2026, 1, 1))

    result = nil
    LedgerEntry.transaction do
      result = query(as_of: Date.new(2026, 1, 31))
    end

    assert_equal 1000, cash_net(result)
  end

  private
    def query(as_of: Date.current, account_ids: nil)
      Engine::QueryLayer.call(Engine::Query.new(ledger: @ledger, as_of: as_of, account_ids: account_ids))
    end

    def post_entry(debit:, credit:, amount:, on:, ledger: @ledger)
      receipt = Engine::PostingOrchestrator.call(
        Engine::Command.new(
          ledger: ledger,
          effective_date: on,
          lines: [
            Engine::Command::Line.new(ledger_account: debit, debit: amount, credit: 0),
            Engine::Command::Line.new(ledger_account: credit, debit: 0, credit: amount)
          ]
        )
      )

      assert receipt.success?, receipt.errors.join(", ")
    end

    def cash_net(result)
      result.balances.find { |balance| balance.ledger_account.name == "Cash" }&.net || BigDecimal(0)
    end
end
