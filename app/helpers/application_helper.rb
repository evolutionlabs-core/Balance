module ApplicationHelper
  def navigation_sections
    business = current_workspace&.business?

    [
      { items: [
        { path: overview_path, svg: "icons/home.svg", text: "Overview" },
        { path: chats_path, svg: "icons/bot.svg", text: "Chat" }
      ] },
      { label: "Sales", items: [
        { path: invoices_path, svg: "icons/invoice.svg", text: "Invoices" },
        { path: customers_path, svg: "icons/users.svg", text: "Customers" },
        { path: services_path, svg: "icons/project.svg", text: "Services" },
        { path: projects_path, svg: "icons/services.svg", text: "Projects" }
      ] },
      { label: "Purchases", items: [
        { path: expenses_path, svg: "icons/banknote.svg", text: "Expenses" },
        ({ path: bills_path, svg: "icons/receipt.svg", text: "Bills" } if business),
        ({ path: vendors_path, svg: "icons/users.svg", text: "Vendors" } if business)
      ].compact },
      { label: "Accounting", items: [
        { path: journal_entries_path, svg: "icons/list.svg", text: "Journal entries" },
        { path: accounts_path, svg: "icons/wallet.svg", text: "Accounts" },
        { path: balance_sheet_path, svg: "icons/gauge.svg", text: "Reports", children: [
          { path: balance_sheet_path, text: "Balance sheet" },
          { path: income_statement_path, text: "Income statement" },
          { path: trial_balance_path, text: "Trial balance" },
          { path: general_ledger_path, text: "General ledger" }
        ] }
      ] }
    ]
  end

  def active_nav?(path)
    return current_page?(root_path) || current_page?(overview_path) if path == overview_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end
end
