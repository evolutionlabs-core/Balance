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
    buckets = daily_series(days: days).group_by { |day| days > 30 ? day[:date].beginning_of_week : day[:date] }

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

  def trial_balance
    raw_balances = raw_by_account

    accounts.values.sort_by(&:name).filter_map do |account|
      raw = raw_balances.fetch(account.id, 0)
      next if raw.zero?

      if raw.positive?
        TrialBalanceLine.new(account: account, debit_kobo: raw, credit_kobo: 0)
      else
        TrialBalanceLine.new(account: account, debit_kobo: 0, credit_kobo: -raw)
      end
    end
  end

  def profit_and_loss(date_range)
    period_from(raw_by_account(date_range))
  end

  private
    attr_reader :workspace

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
