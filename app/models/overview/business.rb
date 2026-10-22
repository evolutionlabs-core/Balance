class Overview::Business < Overview
  def rows
    [
      %i[receivables payables],
      %i[cash_flow],
      %i[income_expenses top_expenses],
      %i[accounts position]
    ]
  end

  def kpis
    [
      cash_kpi,
      period_kpi(:income, :income_kobo, rising_is_good: true),
      period_kpi(:expenses, :expense_kobo, rising_is_good: false),
      period_kpi(current_period.profit_kobo.negative? ? :net_loss : :net_profit, :profit_kobo, rising_is_good: true)
    ]
  end

  def account_subtypes
    %w[cash credit_card]
  end
end
