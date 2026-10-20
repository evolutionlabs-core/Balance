class Overview::Personal < Overview
  def rows
    [
      %i[cash_flow],
      %i[income_expenses top_expenses],
      %i[accounts position]
    ]
  end

  def kpis
    [
      net_worth_kpi,
      period_kpi(:income, :income_kobo, rising_is_good: true),
      period_kpi(:expenses, :expense_kobo, rising_is_good: false),
      period_kpi(current_period.profit_kobo.negative? ? :overspent : :saved, :profit_kobo, rising_is_good: true)
    ]
  end

  def account_subtypes
    %w[cash investment credit_card loan]
  end

  private
    def net_worth_kpi
      today, opening = position ? position.total(:equity) : [ 0, 0 ]
      Kpi.new(key: :net_worth, amount_kobo: today, change_kobo: today - opening, compared_to: :period_start, rising_is_good: true)
    end
end
