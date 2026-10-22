class ReportPeriod
  INCOME_STATEMENT = {
    "this_month" => "This month",
    "last_month" => "Last month",
    "this_quarter" => "This quarter",
    "last_quarter" => "Last quarter",
    "this_year" => "This year",
    "last_year" => "Last year"
  }.freeze

  BALANCE_SHEET_COMPARISONS = {
    "previous_month" => "Previous month end",
    "previous_year" => "Previous year end",
    "none" => "No comparison"
  }.freeze

  def self.income_statement(key, today: Date.current, year_start_month: 1)
    key = INCOME_STATEMENT.key?(key) ? key : "this_month"
    current, previous = income_statement_ranges(key, today, year_start_month)
    [ key, [ column(current), column(previous) ] ]
  end

  def self.balance_sheet(as_of, comparison, year_start_month: 1)
    comparison = BALANCE_SHEET_COMPARISONS.key?(comparison) ? comparison : "previous_month"
    dates = [ as_of ]
    dates << as_of.beginning_of_month - 1 if comparison == "previous_month"
    dates << FinancialYear.start_for(as_of, year_start_month) - 1 if comparison == "previous_year"
    [ comparison, dates.map { |date| [ date.strftime("%b %-d, %Y"), date ] } ]
  end

  def self.income_statement_ranges(key, today, year_start_month)
    year = FinancialYear.range_for(today, year_start_month)

    case key
    when "this_month" then [ today.beginning_of_month..today, today.prev_month.all_month ]
    when "last_month" then [ today.prev_month.all_month, (today.prev_month - 1.month).all_month ]
    when "this_quarter" then [ today.beginning_of_quarter..today, today.prev_quarter.all_quarter ]
    when "last_quarter" then [ today.prev_quarter.all_quarter, (today.prev_quarter - 3.months).all_quarter ]
    when "this_year" then [ year.begin..today, year.begin.prev_year..today.prev_year ]
    when "last_year" then [ year.begin.prev_year..(year.begin - 1), year.begin.prev_year(2)..(year.begin.prev_year - 1) ]
    end
  end
  private_class_method :income_statement_ranges

  def self.column(range)
    [ label(range), range.begin, range.end ]
  end
  private_class_method :column

  def self.label(range)
    from, to = range.begin, range.end

    if from == from.beginning_of_month && to == from.end_of_month
      from.strftime("%b %Y")
    elsif from.year == to.year
      "#{from.strftime("%b %-d")} – #{to.strftime("%b %-d, %Y")}"
    else
      "#{from.strftime("%b %-d, %Y")} – #{to.strftime("%b %-d, %Y")}"
    end
  end
  private_class_method :label
end
