require "test_helper"

class Engine::QueryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "standard_sme")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @bank = @ledger.ledger_accounts.find_by!(name: "Bank")
    @sales = @ledger.ledger_accounts.find_by!(name: "Sales")
    @payroll = @ledger.ledger_accounts.find_by!(name: "Payroll")
  end

  test "returns account balances with signed values" do
    post_entry({ @bank => 150_000, @cash => 0 }, credit: @sales)

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "account_balances")

    assert_equal "success", response[:status]
    accounts = response[:data][:accounts]
    assert_equal @ledger.ledger_accounts.count, accounts.size

    cash = accounts.find { |account| account[:account_id] == @cash.id }
    assert_equal 0, cash[:raw_debit]
    assert_equal 0, cash[:balance]
    assert_equal "debit", cash[:normal_balance]

    bank = accounts.find { |account| account[:account_id] == @bank.id }
    assert_equal 150_000, bank[:raw_debit]
    assert_equal 150_000, bank[:balance]

    sales = accounts.find { |account| account[:account_id] == @sales.id }
    assert_equal 150_000, sales[:raw_credit]
    assert_equal -150_000, sales[:balance]
    assert_equal "credit", sales[:normal_balance]
  end

  test "returns balance sheet with unclosed earnings in equity" do
    post_entry({ @cash => 90_000 }, credit: @sales)
    post_entry({ @payroll => 40_000 }, credit: @cash)

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "balance_sheet")

    assert_equal 50_000, response[:data][:total_assets]
    assert_equal 0, response[:data][:total_liabilities]
    assert_equal 50_000, response[:data][:current_earnings]
    assert_equal 50_000, response[:data][:total_equity]
    assert response[:data][:balance_check]
  end

  test "income statement uses bounded range, not cumulative" do
    post_entry({ @cash => 80_000 }, credit: @sales, effective_date: Date.new(Date.current.year, 1, 15))
    post_entry({ @cash => 20_000 }, credit: @sales, effective_date: Date.new(Date.current.year, 10, 15))

    response = Engine::Query.call(
      ledger_id: @ledger.id,
      query_type: "income_statement",
      options: {
        start_date: Date.new(Date.current.year, 10, 1),
        end_date: Date.new(Date.current.year, 10, 31)
      }
    )

    assert_equal 20_000, response[:data][:total_income]
    assert_equal 20_000, response[:data][:net_income]
  end

  test "personal spending includes owner_draws" do
    personal_ledger = personal_finance_ledger
    groceries = personal_ledger.ledger_accounts.find_by!(name: "Groceries")
    cash = personal_ledger.ledger_accounts.find_by!(name: "Cash")
    personal_spending = personal_ledger.ledger_accounts.find_by!(name: "Personal Spending")

    post_entry({ groceries => 50_000 }, credit: cash, workspace_ledger: personal_ledger)
    post_entry({ personal_spending => 30_000 }, credit: cash, workspace_ledger: personal_ledger)

    response = Engine::Query.call(
      ledger_id: personal_ledger.id,
      query_type: "dashboard",
      options: { workspace_type: "personal" }
    )

    assert_equal 0, response[:data][:income_this_month]
    assert_equal 80_000, response[:data][:spending_this_month]
    assert_equal -80_000, response[:data][:net_movement_this_month]
    assert_nil response[:data][:savings_rate]

    categories = response[:data][:top_spending_categories]
    assert_equal [ { subtype: "groceries", amount: 50_000 }, { subtype: "owner_draws", amount: 30_000 } ],
      categories.sort_by { |category| -category[:amount] }
  end

  test "returns net worth" do
    post_entry({ @cash => 70_000 }, credit: :owner_equity)

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "net_worth")

    assert_equal 70_000, response[:data][:net_worth]
    assert_equal 70_000, response[:data][:total_assets]
    assert_equal 0, response[:data][:total_liabilities]
  end

  test "returns cash position" do
    post_entry({ @cash => 30_000 }, credit: @bank)
    post_entry({ @bank => 12_000 }, credit: @sales)

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "cash_position")

    assert_equal 12_000, response[:data][:cash_position]
    assert_equal 2, response[:data][:accounts].size
  end

  test "returns paginated journal history" do
    3.times { |index| post_entry({ @cash => 10_000 * (index + 1) }, credit: @sales) }

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "journal_history", options: { per_page: 2 })

    assert_equal 2, response[:data][:entries].size
    assert_equal({ page: 1, per_page: 2, total_count: 3, total_pages: 2 }, response[:data][:pagination])

    second_page = Engine::Query.call(ledger_id: @ledger.id, query_type: "journal_history", options: { page: 2, per_page: 2 })
    assert_equal 1, second_page[:data][:entries].size
  end

  test "filters journal history by account" do
    post_entry({ @cash => 10_000 }, credit: @sales)
    post_entry({ @bank => 20_000 }, credit: @sales)

    response = Engine::Query.call(
      ledger_id: @ledger.id,
      query_type: "journal_history",
      options: { account_id: @cash.id }
    )

    assert_equal 1, response[:data][:entries].size
    assert_equal @cash.id, response[:data][:entries].first[:lines].first[:account_id]
  end

  test "returns zeros for empty ledger" do
    empty_workspace = Workspace.create!(name: "Empty Ledger Co", workspace_type: "business")
    empty_ledger = empty_workspace.provision_ledger!(template: "standard_sme")

    response = Engine::Query.call(ledger_id: empty_ledger.id, query_type: "account_balances")

    assert_equal empty_ledger.ledger_accounts.count, response[:data][:accounts].size
    assert response[:data][:accounts].all? { |account| account[:balance].zero? }
    assert response[:data][:accounts].none? { |account| account[:balance].nil? }

    balance_sheet = Engine::Query.call(ledger_id: empty_ledger.id, query_type: "balance_sheet")
    assert balance_sheet[:data][:balance_check]
    assert_equal 0, balance_sheet[:data][:total_assets]
  end

  test "normalizes to integer kobo" do
    post_entry({ @cash => 123_456 }, credit: @sales)

    response = Engine::Query.call(ledger_id: @ledger.id, query_type: "journal_history")

    lines = response[:data][:entries].first[:lines]
    cash_line = lines.find { |line| line[:account_id] == @cash.id }
    assert_equal 123_456, cash_line[:debit]
    assert_kind_of Integer, cash_line[:debit]
    assert_kind_of Integer, cash_line[:credit]
    assert_equal "Cash", cash_line[:account_name]
  end

  private
    def post_entry(debits, credit:, effective_date: Date.current, workspace_ledger: nil)
      entries = debits.reject { |_account, amount| amount.zero? }.map do |account, amount|
        { ledger_account: account, debit: amount, credit: 0 }
      end

      credit_account = credit.is_a?(Symbol) ? @ledger.ledger_accounts.find_by!(subtype: credit) : credit
      entries << { ledger_account: credit_account, debit: 0, credit: debits.values.sum }

      command = Engine::Command.new(
        ledger: workspace_ledger || @ledger,
        effective_date: effective_date,
        lines: entries.map do |line|
          Engine::Command::Line.new(
            ledger_account: line[:ledger_account],
            debit: line[:debit],
            credit: line[:credit]
          )
        end
      )

      receipt = Engine.post(command)
      raise "Entry rejected: #{receipt.errors.join(', ')}" unless receipt.success?
      receipt.entry
    end

    def personal_finance_ledger
      workspace = workspaces(:bola_shop)
      workspace.ledgers.first || workspace.provision_ledger!(template: workspace.ledger_template)
    end
end
