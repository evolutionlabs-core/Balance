module ExpensesHelper
  def expense_account_options(accounts, selected = nil)
    grouped_options_for_select(
      accounts.group_by(&:base_type).map do |base_type, grouped_accounts|
        [ base_type.humanize, grouped_accounts.map { |account| [ account.name, account.id ] } ]
      end,
      selected
    )
  end

  def expense_status(expense)
    tone = case expense.status
    when "posted" then :success
    when "voided" then :neutral
    else :warning
    end

    status_badge(expense.status.humanize, tone: tone)
  end
end
