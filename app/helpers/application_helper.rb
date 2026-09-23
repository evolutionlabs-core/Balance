module ApplicationHelper
  def navigation_sections
    [
      { items: [
        { path: overview_path, svg: "icons/home.svg", text: "Overview" },
        { path: chats_path, svg: "icons/bot.svg", text: "Chat" },
        { path: expenses_path, svg: "icons/banknote.svg", text: "Expenses" },
        { path: invoices_path, svg: "icons/invoice.svg", text: "Invoices" },
        { path: customers_path, svg: "icons/users.svg", text: "Customers" },
        { path: projects_path, svg: "icons/services.svg", text: "Projects" },
        { path: services_path, svg: "icons/project.svg", text: "Services" },
        { path: journal_entries_path, svg: "icons/list.svg", text: "Journal entries" },
        { path: accounts_path, svg: "icons/wallet.svg", text: "Accounts" }
      ] }
    ]
  end

  def active_nav?(path)
    return current_page?(root_path) || current_page?(overview_path) if path == overview_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end
end
