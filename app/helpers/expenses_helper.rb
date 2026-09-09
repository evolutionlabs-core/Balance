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
    classes = expense.posted? ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"
    tag.span(expense.status.humanize, class: "inline-flex rounded-full px-2 py-1 text-xs font-medium #{classes}")
  end

  def expense_payee_options(contacts, selected = nil)
    grouped_options_for_select(
      [ [ "Vendors", contacts.map { |contact| [ contact.name, contact.id ] } ] ],
      selected
    )
  end
end
