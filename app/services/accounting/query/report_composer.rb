module Accounting
  module Query
    class ReportComposer
      def self.balance_sheet(ledger_id:, as_of_date: Date.current)
        accounts = aggregates(ledger_id: ledger_id, as_of_date: as_of_date)

        assets = by_base_type(accounts, "asset")
        liabilities = by_base_type(accounts, "liability")
        equity = by_base_type(accounts, "equity")

        total_assets = signed_total(assets)
        total_liabilities = -signed_total(liabilities)
        posted_equity = -signed_total(equity)
        current_earnings = -signed_total(by_base_type(accounts, "income")) - signed_total(by_base_type(accounts, "expense"))
        total_equity = posted_equity + current_earnings

        Result.new(
          data: {
            as_of_date: as_of_date,
            assets: section(assets),
            total_assets: total_assets,
            liabilities: section(liabilities),
            total_liabilities: total_liabilities,
            equity: section(equity),
            posted_equity: posted_equity,
            current_earnings: current_earnings,
            total_equity: total_equity,
            balance_check: total_assets == total_liabilities + total_equity
          },
          metadata: { as_of_date: as_of_date },
          errors: []
        )
      end

      def self.income_statement(ledger_id:, start_date:, end_date:)
        accounts = aggregates(ledger_id: ledger_id, start_date: start_date, end_date: end_date)

        income = by_base_type(accounts, "income")
        expenses = by_base_type(accounts, "expense")
        total_income = -signed_total(income)
        total_expenses = signed_total(expenses)

        Result.new(
          data: {
            period: { start_date: start_date, end_date: end_date },
            income: section(income),
            total_income: total_income,
            expenses: section(expenses),
            total_expenses: total_expenses,
            net_income: total_income - total_expenses
          },
          metadata: { start_date: start_date, end_date: end_date },
          errors: []
        )
      end

      def self.net_worth(ledger_id:, as_of_date: Date.current)
        accounts = aggregates(ledger_id: ledger_id, as_of_date: as_of_date)

        total_assets = signed_total(by_base_type(accounts, "asset"))
        total_liabilities = -signed_total(by_base_type(accounts, "liability"))

        Result.new(
          data: {
            as_of_date: as_of_date,
            net_worth: total_assets - total_liabilities,
            total_assets: total_assets,
            total_liabilities: total_liabilities
          },
          metadata: { as_of_date: as_of_date },
          errors: []
        )
      end

      def self.cash_position(ledger_id:, as_of_date: Date.current)
        accounts = aggregates(ledger_id: ledger_id, as_of_date: as_of_date)

        Result.new(
          data: {
            as_of_date: as_of_date,
            cash_position: signed_total(by_subtype(accounts, "cash")),
            accounts: section(by_subtype(accounts, "cash"))
          },
          metadata: { as_of_date: as_of_date },
          errors: []
        )
      end

      def self.dashboard(ledger_id:, as_of_date: Date.current, workspace_type: "business")
        workspace_type.to_s == "personal" ? personal_dashboard(ledger_id: ledger_id, as_of_date: as_of_date) : business_dashboard(ledger_id: ledger_id, as_of_date: as_of_date)
      end

      def self.personal_dashboard(ledger_id:, as_of_date: Date.current)
        as_of = aggregates(ledger_id: ledger_id, as_of_date: as_of_date)
        month = month_movement(ledger_id, as_of_date)

        income = -signed_total(by_base_type(month, "income"))
        spending = spending_movement(month)
        net = income - spending

        Result.new(
          data: {
            as_of_date: as_of_date,
            net_worth: net_worth_from(as_of),
            cash_position: cash_position_from(as_of),
            income_this_month: income,
            spending_this_month: spending,
            net_movement_this_month: net,
            savings_rate: savings_rate(income, net),
            top_spending_categories: top_categories(spending_rows(month)),
            recent_transactions: recent_transactions(ledger_id)
          },
          metadata: { workspace_type: "personal", as_of_date: as_of_date },
          errors: []
        )
      end

      def self.business_dashboard(ledger_id:, as_of_date: Date.current)
        as_of = aggregates(ledger_id: ledger_id, as_of_date: as_of_date)
        month = month_movement(ledger_id, as_of_date)

        income = -signed_total(by_base_type(month, "income"))
        expenses = signed_total(by_base_type(month, "expense"))

        Result.new(
          data: {
            as_of_date: as_of_date,
            cash_position: cash_position_from(as_of),
            income_this_month: income,
            expenses_this_month: expenses,
            net_income: income - expenses,
            accounts_receivable: signed_total(by_subtype(as_of, "accounts_receivable")),
            accounts_payable: -signed_total(by_subtype(as_of, "accounts_payable")),
            top_expense_categories: top_categories(month.select { |row| row[:base_type] == "expense" }),
            recent_transactions: recent_transactions(ledger_id)
          },
          metadata: { workspace_type: "business", as_of_date: as_of_date },
          errors: []
        )
      end

      def self.aggregates(ledger_id:, as_of_date: nil, start_date: nil, end_date: nil)
        BalanceAggregator.call(
          ledger_id: ledger_id, as_of_date: as_of_date, start_date: start_date, end_date: end_date
        ).data.fetch(:accounts)
      end

      def self.month_movement(ledger_id, as_of_date)
        aggregates(
          ledger_id: ledger_id,
          start_date: as_of_date.beginning_of_month,
          end_date: as_of_date
        )
      end

      def self.net_worth_from(accounts)
        signed_total(by_base_type(accounts, "asset")) + signed_total(by_base_type(accounts, "liability"))
      end

      def self.cash_position_from(accounts)
        signed_total(by_subtype(accounts, "cash"))
      end

      def self.spending_rows(month)
        month.select { |row| row[:base_type] == "expense" || row[:subtype] == "owner_draws" }
      end

      def self.spending_movement(month)
        signed_total(spending_rows(month))
      end

      def self.savings_rate(income, net)
        return nil unless income.positive?

        (net.to_f / income * 100).round(1)
      end

      def self.top_categories(rows)
        rows.reject { |row| row[:balance].zero? }
          .group_by { |row| row[:subtype] }
          .map { |subtype, grouped| { subtype: subtype, amount: signed_total(grouped) } }
          .sort_by { |category| -category[:amount] }
          .first(5)
      end

      def self.recent_transactions(ledger_id)
        HistoryBuilder.call(ledger_id: ledger_id, page: 1, per_page: 8).data.fetch(:entries)
      end

      def self.by_base_type(accounts, base_type)
        accounts.select { |account| account[:base_type] == base_type }
      end

      def self.by_subtype(accounts, subtype)
        accounts.select { |account| account[:subtype] == subtype }
      end

      def self.signed_total(accounts)
        accounts.sum { |account| account[:balance] }
      end

      def self.section(accounts)
        accounts.map do |account|
          {
            account_id: account[:account_id],
            code: account[:code],
            name: account[:name],
            subtype: account[:subtype],
            normal_balance: account[:normal_balance],
            balance: account[:balance]
          }
        end
      end
      private_class_method :aggregates, :month_movement, :net_worth_from, :cash_position_from,
        :spending_movement, :savings_rate, :top_categories, :recent_transactions,
        :by_base_type, :by_subtype, :signed_total, :section
    end
  end
end
