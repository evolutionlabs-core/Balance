module AccountingEngine
  class FinancialStatements
    Column = Data.define(:label, :from, :to)
    Line = Data.define(:kind, :label, :code, :amounts)
    Outline = Data.define(:label, :amounts, :groups)

    Statement = Data.define(:columns, :lines, :totals) do
      def total(key) = totals.fetch(key)
    end

    GROUP_TITLES = {
      "business" => {
        "current_assets" => "Current assets",
        "non_current_assets" => "Non-current assets",
        "current_liabilities" => "Current liabilities",
        "non_current_liabilities" => "Non-current liabilities"
      },
      "personal" => {
        "current_assets" => "Cash and short-term assets",
        "non_current_assets" => "Investments and property",
        "current_liabilities" => "Cards and short-term debts",
        "non_current_liabilities" => "Loans"
      }
    }.freeze

    DEBIT_SECTIONS = %w[asset expense].freeze

    CASH_FLOW_SECTIONS = {
      operating: %w[accumulated_depreciation accounts_receivable inventory other_asset accounts_payable credit_card tax_payable other_liability],
      investing: %w[fixed_asset investment],
      financing: %w[loan owner_equity owner_draws retained_earnings opening_balance_equity]
    }.freeze

    CASH_FLOW_TITLES = {
      "business" => {
        operating: [ "Operating activities", "Net cash from operating activities" ],
        investing: [ "Investing activities", "Net cash from investing activities" ],
        financing: [ "Financing activities", "Net cash from financing activities" ],
        profit: "Net profit", net: "Net change in cash", opening: "Cash at start of period", closing: "Cash at end of period"
      },
      "personal" => {
        operating: [ "Day-to-day money", "Total day-to-day money" ],
        investing: [ "Investments and property", "Total investments and property" ],
        financing: [ "Loans and contributions", "Total loans and contributions" ],
        profit: "Net savings", net: "Change in cash", opening: "Cash at the start", closing: "Cash at the end"
      }
    }.freeze

    def self.balance_sheet(ledger:, dates:)
      new(ledger).balance_sheet(dates)
    end

    def self.income_statement(ledger:, periods:)
      new(ledger).income_statement(periods)
    end

    def self.cash_flow(ledger:, periods:)
      new(ledger).cash_flow(periods)
    end

    def initialize(ledger)
      @ledger = ledger
      @profile = ledger.workspace.workspace_type
    end

    def balance_sheet(dates)
      columns = dates.map { |label, as_of| Column.new(label: label, from: nil, to: as_of) }
      balances = columns.map { |column| balances_through(column.to) }
      earnings = columns.map { |column| earnings_split(column.to) }
      @outline = []

      lines = []
      assets = section_lines(lines, "Assets", "asset", %w[current_assets non_current_assets], balances, total_kind: :grand_total)
      liabilities = section_lines(lines, "Liabilities", "liability", %w[current_liabilities non_current_liabilities], balances, total_kind: :section_total)
      equity = equity_lines(lines, balances, earnings)

      liabilities_and_equity = add(liabilities, equity)
      lines << Line.new(kind: :grand_total, label: "Total liabilities and #{equity_title.downcase}", code: nil, amounts: liabilities_and_equity)

      Statement.new(
        columns: columns,
        lines: lines,
        totals: {
          assets: assets,
          liabilities: liabilities,
          equity: equity,
          liabilities_and_equity: liabilities_and_equity,
          current_year_earnings: earnings.map(&:last),
          outline: @outline,
          balanced: assets.zip(liabilities_and_equity).map { |left, right| left == right }
        }
      )
    end

    def income_statement(periods)
      columns = periods.map { |label, from, to| Column.new(label: label, from: from, to: to) }
      movements = columns.map { |column| movement(column.from..column.to) }

      if profile == "personal"
        personal_income_statement(columns, movements)
      else
        business_income_statement(columns, movements)
      end
    end

    def cash_flow(periods)
      columns = periods.map { |label, from, to| Column.new(label: label, from: from, to: to) }
      movements = columns.map { |column| movement(column.from..column.to) }
      titles = CASH_FLOW_TITLES.fetch(profile)
      lines = []

      net_profit = Line.new(kind: :account, label: titles[:profit], code: nil, amounts: movements.map { |by_account| profit(by_account) })
      operating = cash_flow_section(lines, *titles[:operating], :operating, movements, lead: net_profit)
      investing = cash_flow_section(lines, *titles[:investing], :investing, movements)
      financing = cash_flow_section(lines, *titles[:financing], :financing, movements)

      net = add(add(operating, investing), financing)
      opening = columns.map { |column| cash_balance(balances_through(column.from - 1)) }
      closing = columns.map { |column| cash_balance(balances_through(column.to)) }
      lines << Line.new(kind: :result, label: titles[:net], code: nil, amounts: net)
      lines << Line.new(kind: :account, label: titles[:opening], code: nil, amounts: opening)
      lines << Line.new(kind: :grand_total, label: titles[:closing], code: nil, amounts: closing)

      Statement.new(
        columns: columns,
        lines: lines,
        totals: {
          operating: operating, investing: investing, financing: financing, net: net, opening: opening, closing: closing,
          reconciled: opening.zip(net, closing).map { |start, change, finish| start + change == finish }
        }
      )
    end

    private
      attr_reader :ledger, :profile

      def cash_flow_section(lines, title, total_label, section, movements, lead: nil)
        rows = accounts.select { |account| CASH_FLOW_SECTIONS.fetch(section).include?(account.subtype) }.filter_map do |account|
          amounts = movements.map { |by_account| -by_account.fetch(account.id, 0) }
          Line.new(kind: :account, label: account.name, code: account.code, amounts: amounts) if amounts.any?(&:nonzero?)
        end
        rows.unshift(lead) if lead

        statement_section(lines, title, rows, movements, always: true, total_label: total_label)
      end

      def cash_balance(by_account)
        accounts.select { |account| account.subtype == "cash" }.sum { |account| by_account.fetch(account.id, 0) }
      end

      def business_income_statement(columns, movements)
        lines = []
        revenue = statement_section(lines, "Revenue", grouped_rows("income", "revenue", movements), movements, always: true)
        cost_of_sales = statement_section(lines, "Cost of sales", grouped_rows("expense", "cost_of_sales", movements), movements)
        gross_profit = subtract(revenue, cost_of_sales)
        lines << Line.new(kind: :result, label: "Gross profit", code: nil, amounts: gross_profit)

        operating_expenses = statement_section(lines, "Operating expenses", grouped_rows("expense", "operating_expenses", movements), movements, always: true)
        operating_profit = subtract(gross_profit, operating_expenses)
        lines << Line.new(kind: :result, label: "Operating profit", code: nil, amounts: operating_profit)

        other_income = statement_section(lines, "Other income", grouped_rows("income", "other_income", movements), movements)
        net = add(operating_profit, other_income)
        lines << Line.new(kind: :grand_total, label: "Net profit", code: nil, amounts: net)

        Statement.new(
          columns: columns,
          lines: lines,
          totals: { income: add(revenue, other_income), expenses: add(cost_of_sales, operating_expenses), net: net }
        )
      end

      def personal_income_statement(columns, movements)
        lines = []
        income = statement_section(lines, "Income", account_rows("income", movements) { true }, movements, always: true)
        expenses = statement_section(lines, "Expenses", account_rows("expense", movements) { true }, movements, always: true)
        net = subtract(income, expenses)
        lines << Line.new(kind: :grand_total, label: "Net savings", code: nil, amounts: net)

        Statement.new(columns: columns, lines: lines, totals: { income: income, expenses: expenses, net: net })
      end

      def section_lines(lines, title, base_type, groups, balances, total_kind:)
        lines << Line.new(kind: :section, label: title, code: nil, amounts: nil)
        outline_groups = []

        totals = groups.map do |group|
          rows = grouped_rows(base_type, group, balances)
          next zeros(balances) if rows.empty?

          group_title = GROUP_TITLES.fetch(profile).fetch(group)
          lines << Line.new(kind: :group, label: group_title, code: nil, amounts: nil)
          lines.concat(rows)
          subtotal = sum(rows)
          lines << Line.new(kind: :subtotal, label: "Total #{group_title.downcase_first}", code: nil, amounts: subtotal)
          outline_groups << Outline.new(label: group_title, amounts: subtotal, groups: [])
          subtotal
        end

        total = totals.reduce { |left, right| add(left, right) }
        lines << Line.new(kind: total_kind, label: "Total #{title.downcase}", code: nil, amounts: total)
        @outline << Outline.new(label: title, amounts: total, groups: outline_groups)
        total
      end

      def equity_lines(lines, balances, earnings)
        lines << Line.new(kind: :section, label: equity_title, code: nil, amounts: nil)

        rows = equity_accounts.filter_map do |account|
          amounts = balances.each_with_index.map do |by_account, index|
            amount = -by_account.fetch(account.id, 0)
            account == retained_earnings_account ? amount + earnings[index].first : amount
          end
          Line.new(kind: :account, label: account.name, code: account.code, amounts: amounts) if amounts.any?(&:nonzero?)
        end

        current_year = earnings.map(&:last)
        rows << Line.new(kind: :account, label: "Current year earnings", code: nil, amounts: current_year) if current_year.any?(&:nonzero?)

        lines.concat(rows)
        total = rows.empty? ? zeros(balances) : sum(rows)
        lines << Line.new(kind: :section_total, label: "Total #{equity_title.downcase}", code: nil, amounts: total)
        @outline << Outline.new(label: equity_title, amounts: total, groups: [])
        total
      end

      def statement_section(lines, title, rows, columns, always: false, total_label: "Total #{title.downcase}")
        return zeros(columns) if rows.empty? && !always

        lines << Line.new(kind: :section, label: title, code: nil, amounts: nil)
        lines.concat(rows)
        total = rows.empty? ? zeros(columns) : sum(rows)
        lines << Line.new(kind: :section_total, label: total_label, code: nil, amounts: total)
        total
      end

      def grouped_rows(base_type, group, columns)
        account_rows(base_type, columns) { |account| AccountSubtypes.statement_group(account.subtype) == group }
      end

      def account_rows(base_type, columns, &select)
        sign = DEBIT_SECTIONS.include?(base_type) ? 1 : -1

        accounts.select { |account| account.base_type == base_type && select.call(account) }.filter_map do |account|
          amounts = columns.map { |by_account| sign * by_account.fetch(account.id, 0) }
          Line.new(kind: :account, label: account.name, code: account.code, amounts: amounts) if amounts.any?(&:nonzero?)
        end
      end

      def accounts
        @accounts ||= ledger.accounts.order(:code).to_a
      end

      def equity_accounts
        accounts.select { |account| account.base_type == "equity" }
      end

      def retained_earnings_account
        @retained_earnings_account ||= equity_accounts.find { |account| account.subtype == "retained_earnings" }
      end

      def equity_title
        profile == "personal" ? "Net worth" : "Equity"
      end

      def earnings_split(as_of)
        year_start = as_of.beginning_of_year
        [ profit(movement(..(year_start - 1))), profit(movement(year_start..as_of)) ]
      end

      def profit(by_account)
        accounts.select { |account| account.base_type.in?(%w[income expense]) }
          .sum { |account| -by_account.fetch(account.id, 0) }
      end

      def balances_through(as_of)
        movement(..as_of)
      end

      def movement(range)
        balances.by_account(range)
      end

      def balances
        @balances ||= AccountingEngine::Balances.new(ledger)
      end

      def sum(rows)
        rows.map(&:amounts).reduce { |left, right| add(left, right) }
      end

      def add(left, right)
        left.zip(right).map { |a, b| a + b }
      end

      def subtract(left, right)
        left.zip(right).map { |a, b| a - b }
      end

      def zeros(columns)
        Array.new(columns.size, 0)
      end
  end
end
