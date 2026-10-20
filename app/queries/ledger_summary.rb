class LedgerSummary
  Period = Struct.new(:income_kobo, :expense_kobo, keyword_init: true) do
    def profit_kobo
      income_kobo - expense_kobo
    end
  end

  CashFlow = Data.define(:opening_kobo, :incoming_kobo, :outgoing_kobo, :closing_kobo, :series)
  AccountAmount = Data.define(:account, :amount_kobo)

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

  def period(days: 30)
    profit_and_loss((Date.current - (days - 1))..Date.current)
  end

  def previous_period(days: 30)
    end_date = Date.current - days
    profit_and_loss((end_date - (days - 1))..end_date)
  end

  def liquid_balance_kobo(as_of: Date.current)
    raw_by_account(..as_of).sum { |account_id, raw| accounts.fetch(account_id).subtype == "cash" ? raw : 0 }
  end

  def performance_series(days: 30)
    running = 0
    data = daily_series(days: days).to_h do |day|
      running += day[:net_kobo]
      [ day[:date], running / 100.0 ]
    end

    [ { name: "Profit / loss", data: data } ]
  end

  def income_expense_series(days: 30)
    buckets = daily_series(days: days).group_by { |day| bucket_start(day[:date], days) }

    [ [ "Income", :income_kobo ], [ "Expenses", :expense_kobo ] ].map do |name, key|
      { name: name, data: buckets.transform_values { |grouped| grouped.sum { |day| day[key] } / 100.0 } }
    end
  end

  def daily_series(days: 30)
    range = (Date.current - (days - 1))..Date.current
    by_date = raw_by_date_and_account(range).group_by { |(date, _account_id), _raw| date }

    range.map do |date|
      period = period_from((by_date[date] || []).to_h { |(_date, account_id), raw| [ account_id, raw ] })
      { date: date, income_kobo: period.income_kobo, expense_kobo: period.expense_kobo, net_kobo: period.profit_kobo }
    end
  end

  def profit_and_loss(date_range)
    period_from(raw_by_account(date_range))
  end

  def cash_flow(days: 30)
    range = (Date.current - (days - 1))..Date.current
    movements = balances ? balances.by_entry(range, subtype: "cash") : {}
    by_date = movements.each_with_object(Hash.new(0)) { |((date, _entry_id), raw), totals| totals[date] += raw }
    opening = liquid_balance_kobo(as_of: range.begin - 1)

    running = opening
    series = range.to_h do |date|
      running += by_date[date]
      [ date, running / 100.0 ]
    end

    CashFlow.new(
      opening_kobo: opening,
      incoming_kobo: movements.values.select(&:positive?).sum,
      outgoing_kobo: -movements.values.select(&:negative?).sum,
      closing_kobo: running,
      series: series
    )
  end

  def expense_breakdown(days: 30)
    raw_by_account((Date.current - (days - 1))..Date.current)
      .filter_map { |account_id, raw| AccountAmount.new(account: accounts.fetch(account_id), amount_kobo: raw) if accounts.fetch(account_id).base_type == "expense" && raw.positive? }
      .sort_by { |row| [ -row.amount_kobo, row.account.code ] }
  end

  def account_balances(subtypes:)
    totals = raw_by_account(..Date.current)

    accounts.values
      .select { |account| account.active? && subtypes.include?(account.subtype) }
      .sort_by(&:code)
      .map do |account|
        raw = totals.fetch(account.id, 0)
        AccountAmount.new(account: account, amount_kobo: account.base_type == "asset" ? raw : -raw)
      end
  end

  private
    attr_reader :workspace

    def bucket_start(date, days)
      if days > 90
        date.beginning_of_month
      elsif days > 30
        date.beginning_of_week
      else
        date
      end
    end

    def period_from(raw_by_account)
      income = raw_by_account.sum { |account_id, raw| accounts.fetch(account_id).base_type == "income" ? -raw : 0 }
      expense = raw_by_account.sum { |account_id, raw| accounts.fetch(account_id).base_type == "expense" ? raw : 0 }
      Period.new(income_kobo: income, expense_kobo: expense)
    end

    def raw_by_account(dates = nil)
      balances ? balances.by_account(dates) : {}
    end

    def raw_by_date_and_account(dates)
      balances ? balances.by_date_and_account(dates) : {}
    end

    def balances
      @balances ||= ledger && AccountingEngine::Balances.new(ledger)
    end

    def ledger
      @ledger ||= workspace.ledgers.first
    end

    def accounts
      @accounts ||= (ledger ? ledger.accounts.to_a : []).index_by(&:id)
    end
end
