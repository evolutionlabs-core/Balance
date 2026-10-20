class Overview
  PERIODS = [ 7, 30, 90, 365 ].freeze
  TOP_EXPENSES = 5

  Kpi = Data.define(:key, :amount_kobo, :change_kobo, :compared_to, :rising_is_good) do
    def negative? = amount_kobo.negative?

    def basis_kobo = amount_kobo - change_kobo

    def net? = %i[net_profit net_loss saved overspent].include?(key)

    def change_percent
      change_kobo * 100.0 / basis_kobo if basis_kobo.positive? && !amount_kobo.negative?
    end
  end

  Slice = Data.define(:label, :amount_kobo, :rest)

  attr_reader :workspace, :days

  def self.for(workspace, days:)
    const_get(workspace.workspace_type.classify).new(workspace, days: days)
  end

  def initialize(workspace, days:)
    @workspace = workspace
    @days = days.clamp(PERIODS.first, PERIODS.last)
  end

  def t(key, **options)
    I18n.t("#{i18n_scope}.#{key}", default: :"overviews.shared.#{key}", **options)
  end

  def rows
    raise NotImplementedError
  end

  def kpis
    raise NotImplementedError
  end

  def account_subtypes
    raise NotImplementedError
  end

  def date_range
    (Date.current - (days - 1))..Date.current
  end

  def current_period
    @current_period ||= summary.period(days: days)
  end

  def previous_period
    @previous_period ||= summary.previous_period(days: days)
  end

  def cash_flow
    @cash_flow ||= summary.cash_flow(days: days)
  end

  def income_expense_series
    summary.income_expense_series(days: days)
  end

  def top_expenses
    breakdown = summary.expense_breakdown(days: days)
    slices = breakdown.first(TOP_EXPENSES).map { |row| Slice.new(label: row.account.name, amount_kobo: row.amount_kobo, rest: false) }
    rest = breakdown.drop(TOP_EXPENSES).sum(&:amount_kobo)

    if rest.positive?
      slices + [ Slice.new(label: t("top_expenses.other"), amount_kobo: rest, rest: true) ]
    else
      slices
    end
  end

  def account_balances
    summary.account_balances(subtypes: account_subtypes).reject { |row| row.amount_kobo.zero? }
  end

  def position
    if ledger
      @position ||= AccountingEngine::FinancialStatements.balance_sheet(
        ledger: ledger,
        dates: [ [ Date.current.strftime("%b %-d, %Y"), Date.current ], [ "Opening", date_range.begin - 1 ] ]
      )
    end
  end

  def receivables
    @receivables ||= AgedBalances.new(workspace, side: :receivables) if ledger
  end

  def payables
    @payables ||= AgedBalances.new(workspace, side: :payables) if ledger
  end

  private
    def i18n_scope
      "overviews.#{self.class.name.demodulize.underscore}"
    end

    def summary
      @summary ||= LedgerSummary.new(workspace)
    end

    def ledger
      @ledger ||= workspace.ledgers.first
    end

    def period_kpi(key, attribute, rising_is_good:)
      amount = current_period.public_send(attribute)
      Kpi.new(key: key, amount_kobo: amount, change_kobo: amount - previous_period.public_send(attribute), compared_to: :previous_period, rising_is_good: rising_is_good)
    end

    def cash_kpi
      Kpi.new(key: :cash, amount_kobo: cash_flow.closing_kobo, change_kobo: cash_flow.closing_kobo - cash_flow.opening_kobo, compared_to: :period_start, rising_is_good: true)
    end
end
