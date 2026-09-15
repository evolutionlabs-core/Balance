class ExpenseReportsController < ApplicationController
  def show
    @from = parsed_date(:from) || 11.months.ago.to_date.beginning_of_month
    @to = parsed_date(:to) || Date.current
    @categories = current_workspace.accounts.expense_accounts.ordered
    @category_id = params[:category_id].presence
    @report = ExpenseReport.new(
      current_workspace,
      date_range: @from..@to,
      category_id: @category_id
    )
  end

  private
    def parsed_date(key)
      Date.iso8601(params[key]) if params[key].present?
    rescue Date::Error
      nil
    end
end
