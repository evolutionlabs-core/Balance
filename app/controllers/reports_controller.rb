class ReportsController < ApplicationController
  def balance_sheet
    return unless ledger

    @report = Accounting::Query.call(ledger_id: ledger.id, query_type: "balance_sheet")[:data]
  end

  def income_statement
    @month = parse_date(params[:month]) || Date.current
    @start_date = @month.beginning_of_month
    @end_date = [ @month.end_of_month, Date.current ].min
    return unless ledger

    @report = Accounting::Query.call(
      ledger_id: ledger.id,
      query_type: "income_statement",
      options: { start_date: @start_date, end_date: @end_date }
    )[:data]
  end

  private
    def ledger
      @ledger ||= current_workspace.ledgers.first
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error, TypeError
      nil
    end
end
