class ExpenseReport
  Ranking = Data.define(:label, :amount_kobo)
  UnusualExpense = Data.define(:expense, :category, :amount_kobo, :average_kobo)

  def initialize(workspace, date_range:, category_id: nil)
    @workspace = workspace
    @date_range = date_range
    @category_id = category_id
  end

  def total_kobo
    expense_lines.sum(:amount_kobo)
  end

  def monthly_totals
    expense_lines
      .group(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .order(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .sum(:amount_kobo)
      .transform_keys(&:to_date)
  end

  def top_categories(limit: 5)
    expense_lines
      .joins(:account)
      .group("accounts.id", "accounts.name")
      .order(Arel.sql("SUM(expense_lines.amount_kobo) DESC"))
      .limit(limit)
      .sum(:amount_kobo)
      .map { |(_id, name), amount| Ranking.new(label: name, amount_kobo: amount) }
  end

  def category_trends
    rows = expense_lines
      .joins(:account)
      .group(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"), "accounts.id", "accounts.name")
      .order(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .sum(:amount_kobo)

    rows.group_by { |(_month, _id, name), _amount| name }.map do |name, category_rows|
      {
        name: name,
        data: category_rows.to_h { |(month, _id, _name), amount| [ month.to_date, amount / 100.0 ] }
      }
    end
  end

  def unusual_spending(limit: 5)
    category_averages = category_average_lines
      .select("expense_lines.account_id, AVG(expense_lines.amount_kobo) AS average_kobo")
      .group("expense_lines.account_id")
      .having("COUNT(*) >= 3")

    expense_lines
      .joins(:account)
      .joins("INNER JOIN (#{category_averages.to_sql}) category_averages ON category_averages.account_id = expense_lines.account_id")
      .where("expense_lines.amount_kobo > category_averages.average_kobo * 2")
      .select("expense_lines.*, category_averages.average_kobo AS category_average_kobo")
      .preload(:account)
      .order(amount_kobo: :desc)
      .limit(limit)
      .map do |line|
        UnusualExpense.new(
          expense: line.expense,
          category: line.account.name,
          amount_kobo: line.amount_kobo,
          average_kobo: line.category_average_kobo.to_i
        )
      end
  end

  private
    attr_reader :workspace, :date_range, :category_id

    def expense_lines
      ExpenseLine.joins(:expense)
        .where(expenses: { workspace_id: workspace.id, status: "posted", payment_date: date_range })
        .then { |lines| category_id.present? ? lines.where(account_id: category_id) : lines }
    end

    def category_average_lines
      ExpenseLine.joins("INNER JOIN expenses category_expenses ON category_expenses.id = expense_lines.expense_id")
        .where(category_expenses: { workspace_id: workspace.id, status: "posted", payment_date: date_range })
        .then { |lines| category_id.present? ? lines.where(account_id: category_id) : lines }
    end
end
