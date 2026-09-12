class LedgerSummary
  Period = Struct.new(:income_kobo, :expense_kobo, keyword_init: true) do
    def profit_kobo
      income_kobo - expense_kobo
    end
  end

  Card = Struct.new(:label, :current, :previous, keyword_init: true) do
    def profit_kobo
      current.profit_kobo
    end

    def income_kobo
      current.income_kobo
    end

    def expense_kobo
      current.expense_kobo
    end

    def change_pct
      base = previous.profit_kobo
      value = current.profit_kobo

      if base.zero?
        return 0.0 if value.zero?

        return value.positive? ? 100.0 : -100.0
      end

      ((value - base).to_f / base.abs * 100).round(1)
    end

    def up?
      current.profit_kobo >= previous.profit_kobo
    end
  end

  TrialBalanceLine = Struct.new(:account, :debit_kobo, :credit_kobo, keyword_init: true)

  BalanceSheet = Struct.new(:assets_kobo, :liabilities_kobo, :equity_kobo, keyword_init: true) do
    def balanced?
      assets_kobo == liabilities_kobo + equity_kobo
    end
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def today
    profit_and_loss(Date.current..Date.current)
  end

  def this_week
    profit_and_loss(Date.current.beginning_of_week..Date.current)
  end

  def this_month
    profit_and_loss(Date.current.beginning_of_month..Date.current)
  end

  def cards
    [
      Card.new(label: "Today", current: today, previous: profit_and_loss((Date.current - 1)..(Date.current - 1))),
      Card.new(label: "This week", current: this_week, previous: profit_and_loss((Date.current.beginning_of_week - 7)..(Date.current - 7))),
      Card.new(label: "This month", current: this_month, previous: profit_and_loss((Date.current.beginning_of_month - 1.month)..(Date.current - 1.month)))
    ]
  end

  def period(days: 30)
    profit_and_loss((Date.current - (days - 1))..Date.current)
  end

  def previous_period(days: 30)
    end_date = Date.current - days
    profit_and_loss((end_date - (days - 1))..end_date)
  end

  def liquid_balance_kobo(as_of: Date.current)
    JournalEntryLine.joins(:journal_entry, :account)
      .where(journal_entries: { workspace_id: workspace.id, entry_date: ..as_of })
      .where(accounts: { account_type: liquid_account_types })
      .where.not(accounts: { detail_type: "Suspense / Clearing" })
      .sum("journal_entry_lines.debit_kobo - journal_entry_lines.credit_kobo")
  end

  def performance_series(days: 30)
    daily_series(days: days).then do |series|
      [ { name: "Profit / loss", data: series.to_h { |day| [ day[:date], day[:net_kobo] / 100.0 ] } } ]
    end
  end

  def income_expense_series(days: 30)
    series = daily_series(days: days)
    [ [ "Income", :income_kobo ], [ "Expenses", :expense_kobo ] ].map do |name, key|
      { name: name, data: series.to_h { |day| [ day[:date], day[key] / 100.0 ] } }
    end
  end

  def daily_series(days: 30)
    start_date = Date.current - (days - 1)
    range = start_date..Date.current

    rows = JournalEntryLine.joins(:journal_entry, :account)
      .where(journal_entries: { workspace_id: workspace.id, entry_date: range })
      .group("journal_entries.entry_date", "accounts.base_type")
      .pluck(Arel.sql("journal_entries.entry_date"), Arel.sql("accounts.base_type"), Arel.sql("SUM(journal_entry_lines.debit_kobo)"), Arel.sql("SUM(journal_entry_lines.credit_kobo)"))

    by_date = rows.group_by { |date, _base_type, _debit, _credit| date }

    range.map do |date|
      day_rows = by_date[date] || []
      income_row = day_rows.find { |_date, base_type, _debit, _credit| base_type == "income" }
      expense_row = day_rows.find { |_date, base_type, _debit, _credit| base_type == "expense" }

      income_kobo = income_row ? income_row[3].to_i - income_row[2].to_i : 0
      expense_kobo = expense_row ? expense_row[2].to_i - expense_row[3].to_i : 0

      { date: date, income_kobo: income_kobo, expense_kobo: expense_kobo, net_kobo: income_kobo - expense_kobo }
    end
  end

  def trial_balance
    raw_balances = JournalEntryLine.joins(:journal_entry)
      .where(journal_entries: { workspace_id: workspace.id })
      .group(:account_id)
      .pluck(:account_id, Arel.sql("SUM(journal_entry_lines.debit_kobo) - SUM(journal_entry_lines.credit_kobo)"))
      .to_h

    workspace.accounts.ordered.filter_map do |account|
      raw = raw_balances[account.id].to_i
      next if raw.zero?

      if raw.positive?
        TrialBalanceLine.new(account: account, debit_kobo: raw, credit_kobo: 0)
      else
        TrialBalanceLine.new(account: account, debit_kobo: 0, credit_kobo: -raw)
      end
    end
  end

  def balance_sheet(as_of: Date.current)
    totals = base_type_totals(as_of: as_of)
    lifetime = profit_and_loss(..as_of)

    assets_kobo = totals["asset"].to_i
    liabilities_kobo = -totals["liability"].to_i
    equity_kobo = -totals["equity"].to_i + lifetime.profit_kobo

    BalanceSheet.new(assets_kobo: assets_kobo, liabilities_kobo: liabilities_kobo, equity_kobo: equity_kobo)
  end

  def profit_and_loss(date_range)
    totals = JournalEntryLine.joins(:journal_entry, :account)
      .where(journal_entries: { workspace_id: workspace.id, entry_date: date_range })
      .group("accounts.base_type")
      .pluck(Arel.sql("accounts.base_type"), Arel.sql("SUM(journal_entry_lines.debit_kobo)"), Arel.sql("SUM(journal_entry_lines.credit_kobo)"))

    income_row = totals.find { |base_type, _debit, _credit| base_type == "income" }
    expense_row = totals.find { |base_type, _debit, _credit| base_type == "expense" }

    income_kobo = income_row ? income_row[2].to_i - income_row[1].to_i : 0
    expense_kobo = expense_row ? expense_row[1].to_i - expense_row[2].to_i : 0

    Period.new(income_kobo: income_kobo, expense_kobo: expense_kobo)
  end

  private

  attr_reader :workspace

  def liquid_account_types
    workspace.personal? ? [ "Cash & Liquid Assets" ] : [ "Bank" ]
  end

  def base_type_totals(as_of:)
    JournalEntryLine.joins(:journal_entry, :account)
      .where(journal_entries: { workspace_id: workspace.id, entry_date: ..as_of })
      .group("accounts.base_type")
      .pluck(Arel.sql("accounts.base_type"), Arel.sql("SUM(journal_entry_lines.debit_kobo) - SUM(journal_entry_lines.credit_kobo)"))
      .to_h
  end
end
