# The overview page for one workspace over a period. Each workspace type has
# a subclass that chooses its headline figures, panels and wording, the way
# Solidus admin pages subclass a shared page component and override its hooks.
#
# Copy lives in config/locales/overviews.en.yml under the type's own scope and
# falls back to `shared`, so supporting a new workspace type means adding a
# subclass and a locale block; the views stay untouched.
class Overview
  PERIODS = [ 7, 30, 90, 365 ].freeze
  TOP_EXPENSES = 5

  # A headline figure. `change_kobo` compares it with the previous period
  # (flows such as income) or with the start of this one (balances such as
  # cash); `rising_is_good` says which way that change should be read.
  Kpi = Data.define(:key, :amount_kobo, :change_kobo, :compared_to, :rising_is_good) do
    def negative? = amount_kobo.negative?

    def basis_kobo = amount_kobo - change_kobo

    # Profit or loss figures, whose starting value is described as one or
    # the other when a percentage cannot be given.
    def net? = %i[net_profit net_loss saved overspent].include?(key)

    # The change as a percentage of where the figure started. Only given when
    # it started above zero and has not gone below it; a percentage across
    # zero (profit turning to loss, a loss deepening) reads the wrong way.
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

  # Rows of panel names, top to bottom. A row holds one panel at full width
  # or two side by side; each name renders overviews/panels/_<name>.
  def rows
    raise NotImplementedError
  end

  def kpis
    raise NotImplementedError
  end

  # Account subtypes listed in the accounts panel.
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

  # The largest expense accounts in the period, with the rest folded into one
  # slice so the chart stays readable.
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

  # Accounts with money in them or owed on them; empty ones are left out.
  def account_balances
    summary.account_balances(subtypes: account_subtypes).reject { |row| row.amount_kobo.zero? }
  end

  # The balance sheet today and the day before the period, so the change in
  # net worth over the period can be read from it.
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
