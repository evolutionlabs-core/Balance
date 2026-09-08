module ExpensesHelper
  def expense_account_options(accounts, selected = nil)
    grouped_options_for_select(
      accounts.group_by(&:account_type).map do |account_type, grouped_accounts|
        [ account_type, grouped_accounts.map { |account| [ account.name, account.id ] } ]
      end,
      selected
    )
  end

  def expense_status(expense)
    status_pill(expense.status.humanize, tone: expense.posted? ? :positive : :pending)
  end

  def expense_payee_options(contacts, selected = nil)
    grouped_options_for_select(
      [ [ "Vendors", contacts.map { |contact| [ contact.name, contact.id ] } ] ],
      selected
    )
  end
end
