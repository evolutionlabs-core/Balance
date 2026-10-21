require "test_helper"

class AccountingEngine::FinancialStatementsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @accounts = @ledger.accounts.index_by(&:key)
  end

  test "groups assets and liabilities and shows contra accounts as deductions" do
    post({ "fixed_assets" => 1_000_000 }, credit: "owner_contributions")
    post({ "depreciation" => 200_000 }, credit: "accumulated_depreciation")
    post({ "bank" => 300_000 }, credit: "loan_payable")
    post({ "owner_draws" => 50_000 }, credit: "bank")

    statement = balance_sheet

    assert_equal [ -200_000 ], line("Accumulated Depreciation").amounts
    assert_equal [ 800_000 ], line("Total non-current assets").amounts
    assert_equal [ 300_000 ], line("Total non-current liabilities").amounts
    assert_equal [ -50_000 ], line("Owner Draws").amounts
    assert_equal [ 1_050_000 ], statement.total(:assets)
    assert_equal statement.total(:assets), statement.total(:liabilities_and_equity)
    assert_equal [ true ], statement.total(:balanced)
  end

  test "moves last year's profit into retained earnings and keeps this year's apart" do
    post({ "bank" => 400_000 }, credit: "sales", on: Date.current.prev_year.end_of_year)
    post({ "bank" => 100_000 }, credit: "sales", on: Date.current)

    statement = balance_sheet

    assert_equal [ 400_000 ], line("Retained Earnings").amounts
    assert_equal [ 100_000 ], line("Current year earnings").amounts
    assert_equal [ true ], statement.total(:balanced)
  end

  test "compares two dates side by side" do
    post({ "bank" => 70_000 }, credit: "sales", on: Date.current.beginning_of_month - 1)
    post({ "bank" => 30_000 }, credit: "sales", on: Date.current)

    statement = balance_sheet(dates: [ [ "now", Date.current ], [ "then", Date.current.beginning_of_month - 1 ] ])

    assert_equal [ 100_000, 70_000 ], line("Bank").amounts
    assert_equal [ true, true ], statement.total(:balanced)
  end

  test "hides accounts with no balance in any column" do
    post({ "bank" => 10_000 }, credit: "sales")

    balance_sheet

    assert_nil @statement.lines.find { |line| line.label == "Inventory" }
  end

  test "business income statement derives gross and operating profit" do
    post({ "bank" => 1_000_000 }, credit: "sales")
    post({ "cost_of_goods_sold" => 400_000 }, credit: "bank")
    post({ "rent" => 150_000 }, credit: "bank")
    post({ "bank" => 20_000 }, credit: "other_income")

    @statement = AccountingEngine::FinancialStatements.income_statement(
      ledger: @ledger, periods: [ [ "this month", Date.current.beginning_of_month, Date.current ] ]
    )

    assert_equal [ 600_000 ], line("Gross profit").amounts
    assert_equal [ 450_000 ], line("Operating profit").amounts
    assert_equal [ 470_000 ], line("Net profit").amounts
    assert_equal [ 470_000 ], @statement.total(:net)
  end

  test "cash flow splits cash movement into operating, investing and financing and reconciles to cash" do
    post({ "bank" => 500_000 }, credit: "owner_contributions", on: Date.current.prev_month)
    post({ "bank" => 300_000 }, credit: "sales")
    post({ "rent" => 50_000 }, credit: "credit_card")
    post({ "inventory" => 120_000 }, credit: "bank")
    post({ "depreciation" => 20_000 }, credit: "accumulated_depreciation")
    post({ "fixed_assets" => 200_000 }, credit: "bank")
    post({ "bank" => 400_000 }, credit: "loan_payable")
    post({ "owner_draws" => 30_000 }, credit: "bank")

    statement = cash_flow

    assert_equal [ 230_000, 0 ], line("Net profit").amounts
    assert_equal [ 50_000, 0 ], line("Credit Card Payable").amounts
    assert_equal [ -120_000, 0 ], line("Inventory").amounts
    assert_equal [ 20_000, 0 ], line("Accumulated Depreciation").amounts
    assert_equal [ 180_000, 0 ], line("Net cash from operating activities").amounts
    assert_equal [ -200_000, 0 ], line("Net cash from investing activities").amounts
    assert_equal [ 370_000, 500_000 ], line("Net cash from financing activities").amounts
    assert_equal [ 350_000, 500_000 ], line("Net change in cash").amounts
    assert_equal [ 500_000, 0 ], line("Cash at start of period").amounts
    assert_equal [ 850_000, 500_000 ], line("Cash at end of period").amounts
    assert_equal [ true, true ], statement.total(:reconciled)
  end

  test "personal cash flow uses plain section names" do
    workspace = workspaces(:ada_store)
    @ledger = workspace.provision_ledger!
    @accounts = @ledger.accounts.index_by(&:key)
    post({ "bank" => 100_000 }, credit: "salary")

    cash_flow

    assert_equal [ 100_000, 0 ], line("Net savings").amounts
    assert_equal [ 100_000, 0 ], line("Total day-to-day money").amounts
    assert_equal [ 100_000, 0 ], line("Cash at the end").amounts
  end

  private
    def cash_flow
      _key, periods = ReportPeriod.income_statement("this_month")
      @statement = AccountingEngine::FinancialStatements.cash_flow(ledger: @ledger, periods: periods)
    end

    def balance_sheet(dates: [ [ "now", Date.current ] ])
      @statement = AccountingEngine::FinancialStatements.balance_sheet(ledger: @ledger, dates: dates)
    end

    def line(label)
      @statement.lines.find { |line| line.label == label } || flunk("no line #{label.inspect}")
    end

    def post(debits, credit:, on: Date.current)
      lines = debits.map { |key, amount| AccountingEngine::Command::Line.new(account: @accounts.fetch(key), debit: amount, credit: 0) }
      lines << AccountingEngine::Command::Line.new(account: @accounts.fetch(credit), debit: 0, credit: debits.values.sum)
      receipt = AccountingEngine.post(AccountingEngine::Command.new(ledger: @ledger, effective_date: on, lines: lines))
      assert receipt.success?, receipt.errors.join(", ")
    end
end
