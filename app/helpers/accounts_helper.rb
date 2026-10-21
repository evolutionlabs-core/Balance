module AccountsHelper
  def account_balance(account, balances)
    sign = account.normal_balance == "debit" ? 1 : -1
    sign * balances.fetch(account.id, 0)
  end

  def account_actions(account, balances)
    if account.active? && !account.system? && account_balance(account, balances).zero?
      button_to("Archive", account_archival_path(account), class: "cursor-pointer bg-transparent font-medium text-balance-teal-700 hover:underline",
        form: { class: "inline", data: { turbo_confirm: "Archive #{account.name}? It will no longer be offered when recording transactions." } })
    elsif !account.active?
      button_to("Restore", account_archival_path(account), method: :delete, class: "cursor-pointer bg-transparent font-medium text-balance-teal-700 hover:underline", form: { class: "inline" })
    end
  end
end
