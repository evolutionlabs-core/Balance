require "test_helper"

class FinancialYearTest < ActiveSupport::TestCase
  test "finds the start of the financial year that contains a date" do
    assert_equal Date.new(2026, 4, 1), FinancialYear.start_for(Date.new(2027, 2, 10), 4)
    assert_equal Date.new(2026, 4, 1), FinancialYear.start_for(Date.new(2027, 3, 31), 4)
    assert_equal Date.new(2027, 4, 1), FinancialYear.start_for(Date.new(2027, 4, 1), 4)
    assert_equal Date.new(2027, 4, 1), FinancialYear.start_for(Date.new(2027, 5, 20), 4)
    assert_equal Date.new(2027, 1, 1), FinancialYear.start_for(Date.new(2027, 5, 20), 1)
  end

  test "year periods follow the financial year" do
    today = Date.new(2027, 2, 10)

    _key, (current, previous) = ReportPeriod.income_statement("this_year", today: today, year_start_month: 4)
    assert_equal [ Date.new(2026, 4, 1), today ], current.last(2)
    assert_equal [ Date.new(2025, 4, 1), Date.new(2026, 2, 10) ], previous.last(2)

    _key, (current, previous) = ReportPeriod.income_statement("last_year", today: today, year_start_month: 4)
    assert_equal [ Date.new(2025, 4, 1), Date.new(2026, 3, 31) ], current.last(2)
    assert_equal [ Date.new(2024, 4, 1), Date.new(2025, 3, 31) ], previous.last(2)

    _key, dates = ReportPeriod.balance_sheet(today, "previous_year", year_start_month: 4)
    assert_equal Date.new(2026, 3, 31), dates.last.last
  end

  test "calendar years are unchanged by default" do
    today = Date.new(2027, 2, 10)

    _key, (current, _previous) = ReportPeriod.income_statement("this_year", today: today)

    assert_equal [ Date.new(2027, 1, 1), today ], current.last(2)
  end
end
