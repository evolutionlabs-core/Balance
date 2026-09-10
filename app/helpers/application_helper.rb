module ApplicationHelper
  def navigation_sections
    [
      { items: [
        { path: dashboard_path, svg: "icons/home.svg", text: "Overview" },
        { path: chats_path, svg: "icons/bot.svg", text: "Chat" },
        { path: expenses_path, svg: "icons/receipt.svg", text: "Expenses" },
        { path: invoices_path, svg: "icons/invoice.svg", text: "Invoices" },
        { path: contacts_path, svg: "icons/users.svg", text: "Contacts" },
        { path: journal_entries_path, svg: "icons/list.svg", text: "Journal entries" },
        { path: accounts_path, svg: "icons/wallet.svg", text: "Accounts" }
      ] }
    ]
  end

  def active_nav?(path)
    return current_page?(root_path) || current_page?(dashboard_path) if path == dashboard_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end
end
