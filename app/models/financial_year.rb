module FinancialYear
  MONTHS = Date::MONTHNAMES.compact.each_with_index.map { |name, index| [ name, index + 1 ] }.freeze

  def self.start_for(date, start_month)
    year = date.month >= start_month ? date.year : date.year - 1
    Date.new(year, start_month, 1)
  end

  def self.range_for(date, start_month)
    start = start_for(date, start_month)
    start..(start.next_year - 1)
  end
end
